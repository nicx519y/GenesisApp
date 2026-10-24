import {verifyVisualAnchor} from './visual.js';
import {execFile} from 'node:child_process';
import {mkdir,writeFile} from 'node:fs/promises';
import {join} from 'node:path';
import {randomUUID} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';
import {now,select,observation,predicate,type Identity,type Snapshot,type UiNode,type Step,type StepRecord} from './model.js';
export interface Device {
 identity(signal:AbortSignal):Promise<Identity>;
 capture(folder:string,signal:AbortSignal):Promise<Snapshot>;
 act(step:Step,snapshot:Snapshot,signal:AbortSignal):Promise<void>;
 close():Promise<void>;
}
function command(args:string[],signal?:AbortSignal,timeout=15000):Promise<Buffer>{return new Promise((resolve,reject)=>{
 const p=execFile('adb',args,{encoding:'buffer',timeout,maxBuffer:16*1024*1024,...(signal?{signal}:{})},(e,out,err)=>e?reject(Error(`设备命令失败：${String(err).slice(0,600)||e.message}`)):resolve(out));
 // execFile's callback runs after the child closes, including on cancellation.
 p.stdin?.end();
});}
export async function devices(){return (await command(['devices'])).toString().split('\n').flatMap(l=>{const m=l.match(/^(\S+)\s+device$/);return m?[m[1]!]:[];});}
export function parseAudio(raw:string,pid:string){if(!/^\d+$/.test(pid)||/Permission Denial|Can't find service/i.test(raw))return {entries:[],state:'unknown'};const entries=raw.split('\n').filter(l=>l.includes('AudioPlaybackConfiguration')&&new RegExp('(?:u/pid:\\d+/'+pid+'\\b|\\bpid[:= ]+'+pid+'\\b)').test(l));return {entries,state:entries.some(l=>/state[:= ]+started/i.test(l))?'started':entries.some(l=>/state[:= ]+paused/i.test(l))?'paused':'none'};}
export const safeApkPath=(path:string)=>/^\/data\/app\/[\w/+=.@~-]+\/base\.apk$/.test(path);
const decode=(s:string)=>s.replace(/&quot;/g,'"').replace(/&apos;/g,"'").replace(/&lt;/g,'<').replace(/&gt;/g,'>').replace(/&amp;/g,'&');
export function parseTree(xml:string):UiNode[]{if(!xml.includes('<hierarchy'))throw Error('设备未返回新的页面树');return [...xml.matchAll(/<node\b([^>]*?)\/?\s*>/g)].map(m=>{
 const attrs=Object.fromEntries([...m[1]!.matchAll(/([\w-]+)="([^"]*)"/g)].map(a=>[a[1],decode(a[2]!)]));const b=attrs.bounds?.match(/\[(\d+),(\d+)\]\[(\d+),(\d+)\]/);return {id:attrs['resource-id']??'',text:attrs.text??'',description:attrs['content-desc']??'',enabled:attrs.enabled==='true',bounds:b?b.slice(1).map(Number) as UiNode['bounds']:[0,0,0,0]};});}
export class AndroidDevice implements Device {
 private frames=new Map<string,string>();private prefix:string[];private treePaths=new Set<string>();private packageName:string;
 constructor(device:string,packageName:string){if(!/^[\w.:-]+$/.test(device)||!/^([a-zA-Z]\w*\.)+[a-zA-Z]\w*$/.test(packageName))throw Error('设备或包名格式无效');this.prefix=['-s',device];this.packageName=packageName;}
 async shell(args:string[],signal?:AbortSignal,timeout?:number){return (await command([...this.prefix,'shell',...args],signal,timeout)).toString();}
 async identity(signal:AbortSignal):Promise<Identity>{
 const state=await this.shell(['dumpsys','trust'],signal);if(/deviceLocked=(?:true|1)\b/.test(state))throw Error('手机已锁屏，请解锁后继续');
 const pkg=await this.shell(['dumpsys','package',this.packageName],signal),pathOutput=await this.shell(['pm','path',this.packageName],signal);const apk=pathOutput.split('\n').find(l=>l.startsWith('package:')&&l.endsWith('/base.apk'))?.slice(8);
 if(!apk||!safeApkPath(apk))throw Error('目标 App 未安装或无法确定安装包');
 const sha=(await this.shell(['sha256sum',apk],signal,60000)).match(/^[a-f0-9]{64}/)?.[0];if(!sha)throw Error('无法校验手机安装包身份');
 const size=await this.shell(['wm','size'],signal),dims=[...size.matchAll(/(\d+)x(\d+)/g)].at(-1);if(!dims)throw Error('无法读取屏幕尺寸');
 return {device:this.prefix[1]!,packageName:this.packageName,version:pkg.match(/versionName=(.*)/)?.[1]?.trim()??'unknown',apkSha256:sha,android:(await this.shell(['getprop','ro.build.version.release'],signal)).trim(),width:Number(dims[1]),height:Number(dims[2])};
 }
 async capture(folder:string,signal:AbortSignal):Promise<Snapshot>{
 signal.throwIfAborted();await mkdir(folder,{recursive:true});const id='frame-'+randomUUID();const screenshot=id+'.png';const warnings:string[]=[];
 const observedAt:NonNullable<Snapshot['observedAt']>={};
 const activity=await this.shell(['dumpsys','activity','activities'],signal);const foreground=activity.match(/(?:mResumedActivity|topResumedActivity)[^\n]*?\s([\w.]+)\//)?.[1]??'';
 observedAt.foreground=now();
 let audio='unknown';try{const pid=(await this.shell(['pidof',this.packageName],signal)).trim().split(/\s+/)[0];const raw=await this.shell(['dumpsys','audio'],signal);const parsed=parseAudio(raw,pid??'');const entries=parsed.entries;audio=parsed.state;observedAt.audio=now();await writeFile(join(folder,id+'.audio.txt'),entries.join('\n'));}catch(e){signal.throwIfAborted();warnings.push('系统音频状态不可用');}
 const png=await command([...this.prefix,'exec-out','screencap','-p'],signal);if(png.toString('hex',0,8)!=='89504e470d0a1a0a')throw Error('截图不是有效 PNG');await writeFile(join(folder,screenshot),png);this.frames.set(id,join(folder,screenshot));
 const xmlPath='/data/local/tmp/'+id+'.xml';this.treePaths.add(xmlPath);let nodes:UiNode[]=[];let treeAvailable=false;
 try{await this.shell(['uiautomator','dump',xmlPath],signal,9000);const xml=await this.shell(['cat',xmlPath],signal);nodes=parseTree(xml);treeAvailable=true;observedAt.ui=now();await writeFile(join(folder,id+'.xml'),xml);}catch(e){signal.throwIfAborted();warnings.push('本次页面树不可用：'+String(e).slice(0,180));}
 finally{await this.shell(['rm','-f',xmlPath],undefined,5000).then(()=>this.treePaths.delete(xmlPath)).catch(()=>{});}
 const result:Snapshot={id,at:now(),observedAt,screenshot,width:png.readUInt32BE(16),height:png.readUInt32BE(20),foreground,audio,nodes,treeAvailable,warnings};await writeFile(join(folder,id+'.json'),JSON.stringify(result,null,2));return result;
 }
 async act(step:Step,s:Snapshot,signal:AbortSignal){const a=step.action;
 if(['tap','swipe'].includes(a.kind)){
 if(s.foreground!==this.packageName)throw Error('当前前台不是目标 App，停止输入以避免误操作');
 let x:number,y:number;if(a.target.kind==='point'||a.target.kind==='image'){if(a.target.kind==='image'){const image=this.frames.get(s.id);if(!image)throw Error('缺少本次截图');await verifyVisualAnchor(image,s,a.target);}x=Math.round(a.target.x*(s.width-1));y=Math.round(a.target.y*(s.height-1));}else{if(!s.treeAvailable)throw Error('缺少本次页面树，不能定位');const nodes=select(s.nodes,a.target);if(nodes.length!==1)throw Error('操作定位不唯一：'+nodes.length);const n=nodes[0]!;if(!n.enabled)throw Error('目标控件未就绪');const [l,t,r,b]=n.bounds;x=Math.round(l+(r-l)*a.target.x);y=Math.round(t+(b-t)*a.target.y);}
 if(a.kind==='tap')await this.shell(['input','tap',String(x),String(y)],signal);else await this.shell(['input','swipe',String(x),String(y),String(Math.round(a.endX*(s.width-1))),String(Math.round(a.endY*(s.height-1))),String(Math.max(a.durationMs,100))],signal);return;
 }
 if(a.kind==='back'||a.kind==='home'){await this.shell(['input','keyevent',a.kind==='back'?'4':'3'],signal);return;}
 if(a.kind==='restart')await this.shell(['am','force-stop',this.packageName],signal);
 if(a.kind==='launch'||a.kind==='restart')await this.shell(['monkey','-p',this.packageName,'-c','android.intent.category.LAUNCHER','1'],signal);
 }
 async close(){for(const path of this.treePaths){await this.shell(['rm','-f',path],undefined,5000);this.treePaths.delete(path);}}
}
export async function executeStep(device:Device,step:Step,folder:string,signal:AbortSignal,before?:Snapshot):Promise<StepRecord>{
 const startedAt=now(),initial=before??await device.capture(folder,signal);await device.act(step,initial,signal);const observationStart=Date.now();let after=await device.capture(folder,signal);const samples:Array<{at:string;value:string}>=[];let verdict:StepRecord['verdict']='unobserved';
 if(step.check){const c=step.check,start=observationStart;while(true){signal.throwIfAborted();const sampledAt=after.observedAt?.[c.source]??after.at;const sampledMs=Date.parse(sampledAt);if(!Number.isFinite(sampledMs)||sampledMs<start||sampledMs>Date.now())throw Error('观测时间不属于本次操作');samples.push({at:sampledAt,value:observation(after,c)});const elapsed=sampledMs-start;
 const ok=predicate(c,samples.map(s=>s.value))&&(c.operator==='stable'||elapsed<=c.timeoutMs);if(c.operator==='stable'?elapsed>=c.timeoutMs:ok){verdict=ok?'passed':'failed';break;}if(elapsed>=c.timeoutMs){verdict='failed';break;}await delay(Math.min(c.sampleMs,c.timeoutMs-elapsed),undefined,{signal});after=await device.capture(folder,signal);}}
 return {...step,before:initial,after,samples,verdict,startedAt,finishedAt:now()};
}
