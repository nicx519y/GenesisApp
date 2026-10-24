import {createHash} from 'node:crypto';
export const runtimeVersion='exploration-1';
export type Selector={kind:'id'|'text'|'description'|'point'|'image';value:string;x:number;y:number};
export type Action={kind:'observe'|'tap'|'swipe'|'back'|'home'|'launch'|'restart';target:Selector;endX:number;endY:number;durationMs:number};
export type Check={source:'foreground'|'audio'|'ui';target:Selector;property:'text'|'exists'|'enabled'|'count';operator:'equals'|'contains'|'greater'|'advances'|'stable';expected:string;timeoutMs:number;sampleMs:number};
export type Step={id:string;description:string;reason:string;action:Action;check:Check|null};
export type UiNode={id:string;text:string;description:string;enabled:boolean;bounds:[number,number,number,number]};
export type Snapshot={id:string;at:string;observedAt?:Partial<Record<Check['source'],string>>;screenshot:string;width:number;height:number;foreground:string;audio:string;nodes:UiNode[];treeAvailable:boolean;warnings:string[]};
export type StepRecord=Step & {before:Snapshot;after:Snapshot;samples:Array<{at:string;value:string}>;verdict:'passed'|'failed'|'unobserved';startedAt:string;finishedAt:string};
export type Identity={device:string;packageName:string;version:string;apkSha256:string;android:string;width:number;height:number};
export type Recipe={title:string;scope:string;preconditions:string;cleanup:'none'|'home';steps:Step[];limitations:string[]};
export type Session={id:string;revision:number;goal:string;device:string;packageName:string;sourceRoot:string;model:string;allowModelScreenshots:boolean;dataSource:'existing'|'mock';preconditions:string;status:'draft'|'exploring'|'needs_input'|'report'|'stopped'|'error';createdAt:string;updatedAt:string;identity?:Identity;engineHash?:string;records:StepRecord[];report:string;limitations:string[];question:string;answer:string;error:string;candidate?:Recipe;confirmation?:{hash:string;at:string};activeRunId?:string};
export type Run={id:string;caseId:string;startedAt:string;finishedAt?:string;status:'running'|'completed'|'stopped'|'error';appResult:'passed'|'failed'|'unknown';mode:'verify'|'regression';identity?:Identity;records:StepRecord[];cleanup:{ok:boolean;detail:string};error:string;packageHash:string;independentSession:boolean};
export type CasePackage={id:string;version:number;sessionId:string;title:string;createdAt:string;status:'candidate'|'verified'|'published';recipe:Recipe;identity:Identity;hash:string;files:Record<string,string>;runIds:string[];publishedAt?:string;compatibilityError?:string};
export const blankSelector:Selector={kind:'text',value:'',x:0,y:0};
export const now=()=>new Date().toISOString();
export const hash=(v:unknown)=>createHash('sha256').update(typeof v==='string'?v:JSON.stringify(v)).digest('hex');
export function validateStep(value:Step){
 if(!value||!/^s[0-9]+$/.test(value.id)||!value.description?.trim()||!value.reason?.trim())throw Error('步骤缺少身份、说明或依据');
 const a=value.action;if(!a||!['observe','tap','swipe','back','home','launch','restart'].includes(a.kind))throw Error('不支持的操作');
 validateSelector(a.target);if(a.kind==='swipe'&&(!Number.isFinite(a.durationMs)||a.durationMs<0||a.durationMs>2000||![a.endX,a.endY].every(x=>Number.isFinite(x)&&x>=0&&x<=1)))throw Error('手势参数无效');
 if(value.check){const c=value.check;validateSelector(c.target);if(!['foreground','audio','ui'].includes(c.source)||!['text','exists','enabled','count'].includes(c.property)||!['equals','contains','greater','advances','stable'].includes(c.operator)||typeof c.expected!=='string'||c.expected.length>500)throw Error('不支持的断言');
 if(!Number.isInteger(c.timeoutMs)||c.timeoutMs<1000||c.timeoutMs>60000||!Number.isInteger(c.sampleMs)||c.sampleMs<500||c.sampleMs>15000||c.sampleMs>c.timeoutMs)throw Error('观察窗口必须明确且处于 1–60 秒范围');}
}
export function validateSelector(s:Selector){if(!s||!['id','text','description','point','image'].includes(s.kind)||typeof s.value!=='string'||s.value.length>64000||![s.x,s.y].every(x=>Number.isFinite(x)&&x>=0&&x<=1))throw Error('定位参数无效');}
export function select(nodes:UiNode[],s:Selector){return nodes.filter(n=>s.kind==='id'?n.id===s.value:s.kind==='text'?n.text===s.value:s.kind==='description'?n.description===s.value:false);}
export function observation(snapshot:Snapshot,c:Check):string {
 if(c.source==='foreground')return snapshot.foreground;
 if(c.source==='audio'){if(snapshot.audio==='unknown')throw Error('缺少音频观测，不能据此判定业务结果');return snapshot.audio;}
 if(!snapshot.treeAvailable)throw Error('当前页面树采集失败，不能使用旧树或推断控件不存在');
 const nodes=select(snapshot.nodes,c.target);if(c.property==='count')return String(nodes.length);if(c.property==='exists')return String(nodes.length>0);
 if(nodes.length!==1)throw Error(`断言定位必须唯一，实际匹配 ${nodes.length} 个`);
 return c.property==='enabled'?String(nodes[0]!.enabled):nodes[0]!.text;
}
function numeric(v:string){if(/^\d+:\d{2}$/.test(v)){const [m,s]=v.split(':').map(Number);return m!*60+s!;}if(!v.trim())return NaN;return Number(v);}
export function predicate(c:Check,values:string[]):boolean {
 const value=values.at(-1);if(value===undefined)return false;
 if(c.operator==='equals')return value===c.expected;
 if(c.operator==='contains')return value.includes(c.expected);
 if(c.operator==='greater')return numeric(value)>numeric(c.expected);
 if(c.operator==='stable')return values.length>=2&&values.every(v=>v===values[0])&&(c.expected===''||value===c.expected);
 return values.length>=2&&numeric(value)>numeric(values[0]!);
}
export function validateRecipe(recipe:Recipe,records:StepRecord[],fixed=false){
 if(!recipe?.title?.trim()||!recipe.scope?.trim()||!recipe.preconditions?.trim()||!['none','home'].includes(recipe.cleanup)||!Array.isArray(recipe.limitations)||!Array.isArray(recipe.steps)||!recipe.steps.length)throw Error('测试方案缺少范围、前提或步骤');
 const ids=new Set<string>();let previous=-1;
 for(const step of recipe.steps){validateStep(step);if(ids.has(step.id))throw Error('步骤 ID 重复');ids.add(step.id);const index=records.findIndex(r=>r.id===step.id);const source=records[index];if(!source||index<=previous)throw Error('方案必须来自实际执行记录并保持顺序');previous=index;
 if(hash(source.action)!==hash(step.action)||hash(source.check)!==hash(step.check))throw Error('操作或断言已修改，必须先实际补测后才能确认');
 if(fixed&&['tap','swipe'].includes(step.action.kind)&&step.action.target.kind==='point'&&!source.before.screenshot)throw Error('坐标定位缺少源截图，不能固化');}
 if(!recipe.steps.some(s=>s.check))throw Error('方案至少需要一个明确断言');
}
