import Fastify from 'fastify';
import {readFile,realpath} from 'node:fs/promises';
import {join,relative,sep} from 'node:path';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
import {discoverRepoRoot} from '@genesis/qa-core';
import {readQaSettings} from '../settings.js';
import {devices} from './device.js';
import {ExplorationService} from './service.js';
import type {Session,Recipe,CasePackage,Run} from './model.js';
export async function buildExplorationApp(root=discoverRepoRoot(),service=new ExplorationService(root)){
 const app=Fastify({logger:false,bodyLimit:1024*1024});await service.initialize();app.addHook('preClose',()=>service.shutdown());
 app.addHook('onRequest',async(req,reply)=>{const host=req.headers.host?.replace(/:\d+$/,'');if(host&&!['localhost','127.0.0.1','[::1]'].includes(host))return reply.code(403).send({error:'仅允许本机访问'});if(req.headers.origin){try{const u=new URL(req.headers.origin);if(!['localhost','127.0.0.1','[::1]'].includes(u.hostname))return reply.code(403).send({error:'禁止跨站请求'});}catch{return reply.code(403).send({error:'无效来源'});}}});
 app.setErrorHandler((e,_req,reply)=>{void reply.code((e as NodeJS.ErrnoException).code==='ENOENT'?404:400).send({error:e instanceof Error?e.message:String(e)});});
 app.get('/api/health',async()=>({ok:true,workflow:'explore-confirm-freeze-replay',version:1}));
 app.get('/api/exploration/bootstrap',async()=>({devices:await devices().catch(()=>[]),model:(await readQaSettings(root)).models.caseImplementation}));
 app.get('/api/exploration/tasks',async()=> (await service.store.all<Session>('tasks')).sort((a,b)=>b.createdAt.localeCompare(a.createdAt)));
 app.post<{Body:Parameters<ExplorationService['create']>[0]}>('/api/exploration/tasks',req=>service.create(req.body));
 app.get<{Params:{id:string}}>('/api/exploration/tasks/:id',req=>service.store.get<Session>('tasks',req.params.id));
 app.post<{Params:{id:string};Body:{revision:number;answer?:string}}>('/api/exploration/tasks/:id/start',req=>service.start(req.params.id,req.body.revision,req.body.answer));
 app.post<{Params:{id:string}}>('/api/exploration/tasks/:id/stop',req=>service.stop(req.params.id));
 app.post<{Params:{id:string};Body:{revision:number;recipe:Recipe}}>('/api/exploration/tasks/:id/confirm',req=>service.confirm(req.params.id,req.body.revision,req.body.recipe));
 app.post<{Params:{id:string};Body:{revision:number}}>('/api/exploration/tasks/:id/freeze',req=>service.freeze(req.params.id,req.body.revision));
 app.post<{Body:{device:string}}>('/api/exploration/recover-device',req=>service.recoverDevice(req.body.device));
 app.get('/api/exploration/cases',async()=> Promise.all((await service.store.all<CasePackage>('cases')).sort((a,b)=>b.createdAt.localeCompare(a.createdAt)).map(async c=>{try{await service.validateBundle(c);return c;}catch(e){return {...c,compatibilityError:String(e)};}})));
 app.post<{Params:{id:string};Body:{mode:'verify'|'regression'}}>('/api/exploration/cases/:id/run',req=>{if(!['verify','regression'].includes(req.body.mode))throw Error('无效运行模式');return service.run(req.params.id,req.body.mode);});
 app.post<{Params:{id:string};Body:{hash:string}}>('/api/exploration/cases/:id/publish',req=>service.publish(req.params.id,req.body.hash));
 app.get('/api/exploration/runs',()=>service.store.all<Run>('runs'));
 app.post<{Params:{id:string}}>('/api/exploration/runs/:id/stop',req=>service.stop(req.params.id));
 app.get<{Params:{kind:'tasks'|'runs';id:string;file:string}}>('/api/exploration/evidence/:kind/:id/:file',async(req,reply)=>{
 const {kind,id,file}=req.params;if(!['tasks','runs'].includes(kind)||!/^frame-[a-f0-9-]+\.(png|xml|json|audio\.txt)$/.test(file))throw Error('无效证据路径');const base=await realpath(join(service.store.folder(kind,id),'evidence')),path=await realpath(join(base,file));if(relative(base,path).startsWith('..'+sep))throw Error('证据越界');reply.header('cache-control','no-store');return reply.type(file.endsWith('.png')?'image/png':'text/plain; charset=utf-8').send(await readFile(path));
 });
 app.get<{Params:{id:string}}>('/api/exploration/cases/:id/download',async(req,reply)=>{const pkg=await service.store.get<CasePackage>('cases',req.params.id);await service.validateBundle(pkg);const folder=join(service.store.folder('cases',pkg.id),'bundle');const result=await promisify(execFile)('tar',['-czf','-','-C',folder,...Object.keys(pkg.files),'manifest.json'],{encoding:'buffer',maxBuffer:16*1024*1024,env:{...process.env,COPYFILE_DISABLE:'1'}});return reply.header('content-disposition',`attachment; filename="${pkg.id}.tar.gz"`).type('application/gzip').send(result.stdout);});
 return app;
}
