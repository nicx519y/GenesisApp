import {engineHash} from './engine.js';
import {visualAnchor} from './visual.js';
import {mkdir,readFile,writeFile,open,unlink} from 'node:fs/promises';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {runInNewContext} from 'node:vm';
import {stringify,parse} from 'yaml';
import {now,hash,runtimeVersion,validateStep,validateRecipe,blankSelector,type Session,type Recipe,type CasePackage,type Run,type Step,type Identity} from './model.js';
import {AndroidDevice,executeStep,type Device} from './device.js';
import {Store} from './store.js';
import {createDecider,type Decide} from './agent.js';
export const scriptFor=(recipe:Recipe)=>`// Generated from confirmed observations. Business expectations live in assertions.yaml.\nexport default async function test(runtime) {\n${recipe.steps.map(s=>`  await runtime.step(${JSON.stringify(s.id)});`).join('\n')}\n}\n`;
export class ExplorationService {
 readonly store:Store;
 private active=new Map<string,{controller:AbortController;promise:Promise<void>}>();
 private locks=new Map<string,Promise<unknown>>();
 constructor(readonly root:string,readonly decide:Decide=createDecider(root),readonly factory:(device:string,pkg:string)=>Device=(d,p)=>new AndroidDevice(d,p)){this.store=new Store(root);}
 async exclusive<T>(key:string,fn:()=>Promise<T>):Promise<T>{const prior=this.locks.get(key)??Promise.resolve();const next=prior.catch(()=>{}).then(fn);this.locks.set(key,next);try{return await next;}finally{if(this.locks.get(key)===next)this.locks.delete(key);}}
 async initialize(){for(const t of await this.store.all<Session>('tasks'))if(t.status==='exploring'){t.status='stopped';t.error='服务中断，保留原始记录；请核对设备现场后继续';delete t.confirmation;await this.store.save('tasks',t);}for(const r of await this.store.all<Run>('runs'))if(r.status==='running'){r.status='error';r.finishedAt=now();r.error='服务中断；本次验证无效，设备占用需要核对';await this.store.save('runs',r);}}
 async shutdown(){for(const a of this.active.values())a.controller.abort();await Promise.allSettled([...this.active.values()].map(a=>a.promise));}
 async create(input:{goal:string;device:string;packageName:string;model:string;sourceRoot?:string;allowModelScreenshots:boolean;dataSource:'existing'|'mock';preconditions:string}){
 if(input?.allowModelScreenshots!==true)throw Error('请先明确允许将本次应用截图发送给 Codex 模型');
 if(!input?.goal?.trim()||input.goal.length>5000||!input.preconditions?.trim()||!['existing','mock'].includes(input.dataSource)||!input.model||!/^[\w.-]{1,128}$/.test(input.model)||!input.device||!input.packageName)throw Error('请填写测试目标、设备、包名、模型、数据来源和测试前提');
 this.factory(input.device,input.packageName);
 const s:Session={id:'task-'+randomUUID(),revision:1,goal:input.goal,device:input.device,packageName:input.packageName,sourceRoot:input.sourceRoot??'',model:input.model,allowModelScreenshots:true,dataSource:input.dataSource,preconditions:input.preconditions,status:'draft',createdAt:now(),updatedAt:now(),records:[],report:'',limitations:[],question:'',answer:'',error:''};await this.store.save('tasks',s);return s;
 }
 async lease(device:string){const folder=join(this.store.base,'leases');await mkdir(folder,{recursive:true});const path=join(folder,hash(device)+'.json');let handle;try{handle=await open(path,'wx');}catch(e){if((e as NodeJS.ErrnoException).code==='EEXIST')throw Error('设备正被占用，或上次服务中断尚未核对；请等待或解除中断占用');throw e;}await handle.writeFile(JSON.stringify({pid:process.pid,device,at:now()}));await handle.close();return async()=>unlink(path);}
 async recoverDevice(device:string){const path=join(this.store.base,'leases',hash(device)+'.json'),owner=JSON.parse(await readFile(path,'utf8'));try{process.kill(owner.pid,0);throw Error('占用进程仍存在，不能解除');}catch(e){if((e as NodeJS.ErrnoException).code!=='ESRCH')throw e;}await unlink(path);return {released:true};}
 async start(id:string,revision:number,answer=''){return this.exclusive(id,async()=>{
 const s=await this.store.get<Session>('tasks',id);if(s.revision!==revision)throw Error('任务已变化，请刷新');if(this.active.has(id)||s.status==='exploring')throw Error('任务正在执行');if(!['draft','needs_input','stopped','error','report'].includes(s.status))throw Error('任务状态不可执行');
 await this.store.event(s.id,{type:'resume_requested',previousStatus:s.status,previousError:s.error,answer});const release=await this.lease(s.device);const controller=new AbortController();s.status='exploring';s.answer=answer;s.error='';s.question='';delete s.confirmation;delete s.candidate;s.revision++;s.updatedAt=now();await this.store.save('tasks',s);
 const promise=this.explore(s,controller.signal).catch(async e=>{s.status=controller.signal.aborted?'stopped':'error';s.error=String(e);await this.store.event(s.id,{type:'task_error',error:s.error});s.updatedAt=now();s.revision++;await this.store.save('tasks',s);}).finally(async()=>{try{if(!s.error.startsWith('设备清理失败'))await release();}finally{this.active.delete(id);}});this.active.set(id,{controller,promise});return s;
 });}
 async explore(s:Session,signal:AbortSignal){const device=this.factory(s.device,s.packageName),folder=join(this.store.folder('tasks',s.id),'evidence');let cleanupError='';let lastFailure='';let repeatedFailure=0;
 try{if(s.records.length&&s.engineHash!==engineHash)throw Error('探索运行器已更新，请新建任务生成本版证据');s.engineHash=engineHash;const identity=await device.identity(signal);if(s.identity&&s.records.length&&hash(s.identity)!==hash(identity))throw Error('设备或应用身份已变化，请新建测试任务，不能混用旧探索证据');s.identity=identity;await this.store.event(s.id,{type:'identity',identity:s.identity});await this.store.save('tasks',s);
 if(!s.records.length){const initial=await device.capture(folder,signal);await device.act({id:'s0',description:'探索起点',reason:'保留数据重新启动，保证后续可独立重跑',action:{kind:'restart',target:blankSelector,endX:0,endY:0,durationMs:0},check:null},initial,signal);}
 for(let turn=0;turn<60;turn++){signal.throwIfAborted();const snapshot=await device.capture(folder,signal);const decision=await this.decide(s,snapshot,folder,signal);signal.throwIfAborted();await this.store.event(s.id,{type:'decision',snapshot:snapshot.id,decision});
 if(decision.kind==='ask'){s.status='needs_input';s.question=decision.message;break;}
 if(decision.kind==='finish'){
 s.report=decision.message;s.limitations=decision.limitations;s.status='report';const selected=decision.selectedStepIds.map(id=>{const record=s.records.find(r=>r.id===id);if(!record)throw Error('AI 引用了不存在的执行步骤');const {id:stepId,description,reason,action,check}=record;return {id:stepId,description,reason,action,check};});
 if(selected.length){const candidate:Recipe={title:decision.title,scope:decision.scope,preconditions:s.preconditions,cleanup:'none',steps:selected,limitations:decision.limitations};validateRecipe(candidate,s.records);s.candidate=candidate;}break;
 }
 if(!decision.step)throw Error('AI 缺少可执行步骤');const step={...decision.step,id:'s'+(s.records.length+1)};if(step.action&&step.action.kind!=='swipe')step.action={...step.action,endX:0,endY:0,durationMs:0};try{validateStep(step);}catch(e){s.error='决策格式需要修正：'+String(e);await this.store.event(s.id,{type:'decision_validation_error',error:s.error});s.revision++;await this.store.save('tasks',s);continue;}
 await this.store.event(s.id,{type:'action_start',step,before:snapshot.id});try{const record=await executeStep(device,step,folder,signal,snapshot);s.records.push(record);s.error='';lastFailure='';repeatedFailure=0;await this.store.event(s.id,{type:'action_end',record});}catch(e){signal.throwIfAborted();s.error=String(e);await this.store.event(s.id,{type:'action_error',step,error:s.error});const failureKey=hash({action:step.action,check:step.check,error:s.error});repeatedFailure=failureKey===lastFailure?repeatedFailure+1:1;lastFailure=failureKey;if(repeatedFailure>=2){s.status='report';s.report='本轮执行遇到重复的工程阻碍，已保留截图和完整操作日志。未完成部分不计为通过。';s.limitations=[s.error];break;}}
 s.updatedAt=now();s.revision++;await this.store.save('tasks',s);
 }
 if(s.status==='exploring'){s.status='needs_input';s.question='本轮已达到 60 步，请查看已覆盖范围后决定是否继续。';}
 }finally{try{await device.close();}catch(e){cleanupError=String(e);}await this.store.event(s.id,{type:'cleanup',ok:!cleanupError,error:cleanupError});if(cleanupError){s.status='error';s.error='设备清理失败：'+cleanupError;}s.updatedAt=now();s.revision++;await this.store.save('tasks',s);}
 }
 async stop(id:string){const task=this.active.get(id);if(task){task.controller.abort();await task.promise;}return {stopped:true};}
 async confirm(id:string,revision:number,recipe:Recipe){return this.exclusive(id,async()=>{const s=await this.store.get<Session>('tasks',id);if(s.revision!==revision||s.status!=='report'||this.active.has(id))throw Error('任务未完成或已变化');validateRecipe(recipe,s.records);s.candidate=recipe;s.confirmation={hash:hash(recipe),at:now()};s.updatedAt=now();s.revision++;await this.store.save('tasks',s);return s;});}
 async freeze(id:string,revision:number){return this.exclusive(id,async()=>{const s=await this.store.get<Session>('tasks',id);if(s.revision!==revision||!s.identity||!s.candidate||s.confirmation?.hash!==hash(s.candidate)||s.status!=='report')throw Error('请先确认本次报告中的测试方案');validateRecipe(s.candidate,s.records,true);
 const recipe=structuredClone(s.candidate);for(const step of recipe.steps){if(['tap','swipe'].includes(step.action.kind)&&step.action.target.kind==='point'){const source=s.records.find(r=>r.id===step.id)!;step.action.target=await visualAnchor(join(this.store.folder('tasks',s.id),'evidence',source.before.screenshot),source.before,step.action.target);}}const caseId='case-'+randomUUID();const bundle=join(this.store.folder('cases',caseId),'bundle');await mkdir(bundle,{recursive:true});
 const files:Record<string,string>={
 'case.yaml':stringify({schema:1,id:caseId,version:1,runtime:runtimeVersion,engineHash,title:recipe.title,packageName:s.packageName,dataSource:s.dataSource,preconditions:recipe.preconditions,identity:s.identity,cleanup:recipe.cleanup,extensions:[]}),
 'scenario.md':`# ${recipe.title}\n\n${recipe.scope}\n\n前提：${recipe.preconditions}\n\n${recipe.steps.map((st,i)=>`${i+1}. ${st.description}\n   依据：${st.reason}\n   ${st.check?'断言：'+JSON.stringify(st.check):'导航／操作，无独立通过判定'}`).join('\n\n')}\n\n覆盖限制：\n${recipe.limitations.map(x=>'- '+x).join('\n')}\n`,
 'test.ts':scriptFor(recipe),
 'assertions.yaml':stringify(Object.fromEntries(recipe.steps.filter(st=>st.check).map(st=>[st.id,st.check]))),
 'locators.yaml':stringify(Object.fromEntries(recipe.steps.map(st=>[st.id,{action:st.action.target,check:st.check?.target??null}]))),
 'recipe.json':JSON.stringify(recipe,null,2),
 'provenance.json':JSON.stringify({schema:1,sessionId:id,sourceEngineHash:s.engineHash??'legacy',candidateEngineHash:engineHash,confirmedAt:s.confirmation.at,confirmedHash:s.confirmation.hash,sourceSteps:recipe.steps.map(st=>({id:st.id,hash:hash(s.records.find(r=>r.id===st.id))})),limitations:recipe.limitations},null,2),
 'README.md':'使用平台“验证”进行独立重跑。命令行：npm run qa:bundle -- <本目录绝对路径> <设备序列号>。\n脚本只调度已确认步骤；断言由运行器独立计算。扩展为空表示无需 App QA 埋点。\n'};
 const hashes=Object.fromEntries(Object.entries(files).map(([name,content])=>[name,hash(content)]));for(const [name,content] of Object.entries(files))await writeFile(join(bundle,name),content);
 const pkg:CasePackage={id:caseId,version:1,sessionId:id,title:recipe.title,createdAt:now(),status:'candidate',recipe,identity:s.identity,hash:hash(hashes),files:hashes,runIds:[]};await writeFile(join(bundle,'manifest.json'),JSON.stringify({schema:1,runtime:runtimeVersion,hash:pkg.hash,files:hashes},null,2));await this.store.save('cases',pkg);return pkg;
 });}
 async validateBundle(pkg:CasePackage){const folder=join(this.store.folder('cases',pkg.id),'bundle');await verifyBundle(folder,pkg.hash);}
 async run(id:string,mode:'verify'|'regression'='verify'){return this.exclusive(id,async()=>{
 const pkg=await this.store.get<CasePackage>('cases',id);if(mode==='regression'&&pkg.status!=='published')throw Error('回归只能运行已发布 Case');if(mode==='verify'&&pkg.status==='published')throw Error('已发布 Case 请使用回归运行');await this.validateBundle(pkg);
 const release=await this.lease(pkg.identity.device),controller=new AbortController();const r:Run={id:'run-'+randomUUID(),caseId:id,startedAt:now(),status:'running',appResult:'unknown',mode,records:[],cleanup:{ok:false,detail:'尚未释放'},error:'',packageHash:pkg.hash,independentSession:true};pkg.runIds.push(r.id);await this.store.save('cases',pkg);await this.store.save('runs',r);
 const promise=this.execute(pkg,r,controller.signal).finally(async()=>{try{if(r.cleanup.ok)await release();}finally{this.active.delete(r.id);}});this.active.set(r.id,{controller,promise});return r;
 });}
 async execute(pkg:CasePackage,r:Run,signal:AbortSignal){const device=this.factory(pkg.identity.device,pkg.identity.packageName),folder=join(this.store.folder('runs',r.id),'evidence');
 try{r.identity=await device.identity(signal);if((r.mode==='verify'&&r.identity.apkSha256!==pkg.identity.apkSha256)||r.identity.android!==pkg.identity.android||r.identity.width!==pkg.identity.width||r.identity.height!==pkg.identity.height)throw Error('安装包、系统或屏幕与验证目标不同；需要新目标版本验证');
 const initial=await device.capture(folder,signal);const reset:Step={id:'s0',description:'独立会话：保留数据重新启动 App',reason:'避免依赖探索会话的内存和页面状态',action:{kind:'restart',target:blankSelector,endX:0,endY:0,durationMs:0},check:null};await executeStep(device,reset,folder,signal,initial);
 const source=await readFile(join(this.store.folder('cases',pkg.id),'bundle/test.ts'),'utf8');
 await executeGeneratedScript(source,pkg.recipe,async step=>{signal.throwIfAborted();const record=await executeStep(device,step,folder,signal);r.records.push(record);await this.store.save('runs',r);return record.verdict!=='failed';});
 r.appResult=r.records.some(st=>st.verdict==='failed')?'failed':'passed';r.status='completed';
 }catch(e){r.status=signal.aborted?'stopped':'error';r.error=String(e);r.appResult='unknown';}
 finally{try{if(pkg.recipe.cleanup==='home'){const cleanupSignal=AbortSignal.timeout(20000);const frame=await device.capture(folder,cleanupSignal);await device.act({id:'s0',description:'结束后返回桌面',reason:'已确认结束处理',action:{kind:'home',target:blankSelector,endX:0,endY:0,durationMs:0},check:null},frame,cleanupSignal);}await device.close();r.cleanup={ok:true,detail:'本次设备命令已结束，临时页面树已释放；账号和应用数据保留'};}catch(e){r.cleanup={ok:false,detail:String(e)};r.status='error';r.appResult='unknown';}r.finishedAt=now();await this.store.save('runs',r);
 await this.exclusive(pkg.id,async()=>{const current=await this.store.get<CasePackage>('cases',pkg.id);if(current.status!=='published')current.status=await this.publishable(current)?'verified':'candidate';await this.store.save('cases',current);});}
 }
 async publishable(pkg:CasePackage){const runs=await Promise.all(pkg.runIds.map(id=>this.store.get<Run>('runs',id)));const verification=runs.filter(r=>r.mode==='verify');const last=verification.slice(-3);if(last.length!==3||last.some(r=>r.records.length!==pkg.recipe.steps.length||r.records.some((record,i)=>record.id!==pkg.recipe.steps[i]?.id)||r.status!=='completed'||!r.cleanup.ok||r.packageHash!==pkg.hash||!r.independentSession||!r.identity||r.identity.apkSha256!==pkg.identity.apkSha256))return false;
 // Stable bug reproductions are valid assets, but sporadic app outcomes are not silently approved.
 return last.every(r=>r.appResult===last[0]!.appResult&&hash(r.records.map(x=>[x.id,x.verdict]))===hash(last[0]!.records.map(x=>[x.id,x.verdict])));
 }
 async publish(id:string,expectedHash:string){return this.exclusive(id,async()=>{const pkg=await this.store.get<CasePackage>('cases',id);await this.validateBundle(pkg);if(pkg.hash!==expectedHash||!await this.publishable(pkg))throw Error('发布需要同一产物最近三次独立验证结果一致、证据完整且清理成功');pkg.status='published';pkg.publishedAt=now();await this.store.save('cases',pkg);return pkg;});}
 async wait(id:string){await this.active.get(id)?.promise;}
}
export async function verifyBundle(folder:string,expectedHash?:string){
 const manifest=JSON.parse(await readFile(join(folder,'manifest.json'),'utf8')) as {runtime:string;hash:string;files:Record<string,string>};if(manifest.runtime!==runtimeVersion||manifest.hash!==hash(manifest.files)||expectedHash&&manifest.hash!==expectedHash)throw Error('Case 包版本或完整性不匹配');
 const required=['case.yaml','scenario.md','test.ts','assertions.yaml','locators.yaml','recipe.json','provenance.json','README.md'];if(Object.keys(manifest.files).sort().join()!==required.sort().join())throw Error('Case 包文件不完整');for(const file of required)if(hash(await readFile(join(folder,file),'utf8'))!==manifest.files[file])throw Error('Case 包文件发生变化：'+file);
 const recipe=JSON.parse(await readFile(join(folder,'recipe.json'),'utf8')) as Recipe;const meta=parse(await readFile(join(folder,'case.yaml'),'utf8'));if(meta.runtime!==runtimeVersion||meta.engineHash!==engineHash||!Array.isArray(meta.extensions)||meta.extensions.length)throw Error('运行器版本或扩展尚未验证');
 for(const step of recipe.steps)validateStep(step);if(await readFile(join(folder,'test.ts'),'utf8')!==scriptFor(recipe))throw Error('执行脚本与声明的步骤不一致');
 if(hash(parse(await readFile(join(folder,'assertions.yaml'),'utf8')))!==hash(Object.fromEntries(recipe.steps.filter(s=>s.check).map(s=>[s.id,s.check]))))throw Error('独立断言与方案不一致');
 return {recipe,meta,manifest};
}

export async function executeGeneratedScript(source:string,recipe:Recipe,execute:(step:Step)=>Promise<boolean>){
 if(source!==scriptFor(recipe))throw Error('执行脚本不是当前方案的固定生成结果');
 let index=0;const failure=Symbol('app-failure');
 const fn=runInNewContext('('+source.replace('export default ','')+')',Object.create(null),{timeout:1000}) as (runtime:{step:(id:string)=>Promise<void>})=>Promise<void>;
 try{await fn(Object.freeze({step:async(id:string)=>{const step=recipe.steps[index++];if(!step||step.id!==id)throw Error('脚本调用顺序与方案不符');if(!await execute(step))throw failure;}}));}catch(e){if(e!==failure)throw e;}
}
