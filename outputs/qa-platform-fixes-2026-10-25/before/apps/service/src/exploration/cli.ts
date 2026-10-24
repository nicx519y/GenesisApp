import {discoverRepoRoot} from '@genesis/qa-core';
import {resolve,join} from 'node:path';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import {verifyBundle,executeGeneratedScript,ExplorationService} from './service.js';
import {AndroidDevice,executeStep} from './device.js';
import {blankSelector,now} from './model.js';
const folder=resolve(process.argv[2]??''),serial=process.argv[3];
if(!process.argv[2]||!serial)throw Error('用法：npm run qa:bundle -- <Case 包目录> <设备序列号>');
const {recipe,meta,manifest}=await verifyBundle(folder),device=new AndroidDevice(serial,meta.packageName),controller=new AbortController();
const release=await new ExplorationService(discoverRepoRoot()).lease(serial);
const stop=()=>controller.abort();process.once('SIGINT',stop);process.once('SIGTERM',stop);
const output=resolve('reports','exploration-cli','run-'+randomUUID());await mkdir(output,{recursive:true});
const report:{startedAt:string;packageHash:string;status:string;records:unknown[];error?:string;cleanup?:boolean;finishedAt?:string}={startedAt:now(),packageHash:manifest.hash,status:'running',records:[]};
try{const identity=await device.identity(controller.signal);if(identity.apkSha256!==meta.identity.apkSha256||identity.android!==meta.identity.android||identity.width!==meta.identity.width||identity.height!==meta.identity.height)throw Error('运行目标与包中验证环境不同');
 await executeStep(device,{id:'s0',description:'独立启动',reason:'新的执行会话',action:{kind:'restart',target:blankSelector,endX:0,endY:0,durationMs:0},check:null},output,controller.signal);
 report.status='passed';await executeGeneratedScript(await readFile(join(folder,'test.ts'),'utf8'),recipe,async step=>{const record=await executeStep(device,step,output,controller.signal);report.records.push(record);if(record.verdict==='failed'){report.status='failed';process.exitCode=1;return false;}return true;});
}catch(e){report.status=controller.signal.aborted?'stopped':'error';report.error=String(e);process.exitCode=2;}
finally{try{if(recipe.cleanup==='home'){const signal=AbortSignal.timeout(20000),s=await device.capture(output,signal);await device.act({id:'s0',description:'恢复',reason:'确认方案',action:{kind:'home',target:blankSelector,endX:0,endY:0,durationMs:0},check:null},s,signal);}await device.close();report.cleanup=true;await release();}catch(e){report.cleanup=false;report.error=String(e);report.status='error';process.exitCode=2;}report.finishedAt=now();await writeFile(join(output,'report.json'),JSON.stringify(report,null,2));console.log(JSON.stringify({report:join(output,'report.json'),status:report.status}));}
