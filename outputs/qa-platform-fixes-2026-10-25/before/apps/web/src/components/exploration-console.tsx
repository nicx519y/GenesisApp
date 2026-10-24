'use client';
import {useEffect,useState,type ReactNode} from 'react';
import {Alert,Button,Input,Link,Text,Textarea} from '@chakra-ui/react';
import type {Session,CasePackage,Run,Recipe} from '../../../service/src/exploration/model';
import type {ExplorationPreferences} from '../../../service/src/exploration/preferences';
import {FeedbackToast} from './ui/toaster';
import {Check,Choice,Empty,FormField,Panel,Records,StateBadge,date,labels} from './exploration-ui';
import {DetailMeta,DetailTabs,Glyph,ListRow,MasterDetail} from './exploration-layout';
import styles from './exploration-console.module.css';
const pages=[{id:'tasks',name:'测试任务',icon:'activity'},{id:'reports',name:'测试报告',icon:'report'},{id:'cases',name:'Case 管理',icon:'cases'},{id:'runs',name:'运行记录',icon:'runs'},{id:'settings',name:'Settings',icon:'settings'}] as const;
type Page=typeof pages[number]['id'];
const defaults:ExplorationPreferences={model:'',packageName:'com.worldo.ai',preconditions:'使用手机上已有账号和现有数据，保留账号与缓存。',preferredDevice:''};
async function request<T>(path:string,body?:unknown):Promise<T>{
 const response=await fetch('/api/exploration/'+path,{...(body!==undefined?{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)}:{}),cache:'no-store'});
 const value=await response.json().catch(()=>{throw Error('测试服务暂时不可用，请稍后重试。');});if(!response.ok)throw Error(value.error??'请求失败');return value;
}
function Notice({children,status='info'}:{children:ReactNode;status?:'info'|'error'|'success'|'warning'}){return <Alert.Root status={status} size="sm" borderRadius="md"><Alert.Indicator/><Alert.Content><Alert.Description fontSize="xs" whiteSpace="pre-wrap" overflowWrap="anywhere">{children}</Alert.Description></Alert.Content></Alert.Root>;}
export function ExplorationConsole(){
 const [page,setPage]=useState<Page>('tasks'),[tasks,setTasks]=useState<Session[]>([]),[cases,setCases]=useState<CasePackage[]>([]),[runs,setRuns]=useState<Run[]>([]);
 const [selected,setSelected]=useState(''),[caseId,setCaseId]=useState(''),[runId,setRunId]=useState(''),[search,setSearch]=useState(''),[filter,setFilter]=useState('all'),[showOld,setShowOld]=useState(false);
 const [error,setError]=useState(''),[connection,setConnection]=useState(''),[busy,setBusy]=useState(false),[success,setSuccess]=useState(''),[loading,setLoading]=useState(true);
 const [devices,setDevices]=useState<string[]>([]),[device,setDevice]=useState(''),[model,setModel]=useState(''),[goal,setGoal]=useState(''),[pkg,setPkg]=useState(defaults.packageName),[data,setData]=useState<'existing'|'mock'>('existing'),[preconditions,setPreconditions]=useState(defaults.preconditions),[consent,setConsent]=useState(false);
 const [preferences,setPreferences]=useState<ExplorationPreferences>(defaults),[savedPreferences,setSavedPreferences]=useState<ExplorationPreferences>(defaults),[answer,setAnswer]=useState(''),[draft,setDraft]=useState<Recipe|null>(null);
 const task=tasks.find(t=>t.id===selected),currentCase=cases.find(c=>c.id===caseId),currentRun=runs.find(r=>r.id===runId);
 const activeCount=tasks.filter(t=>t.status==='exploring').length+runs.filter(r=>r.status==='running').length;
 function navigate(next:Page){setPage(next);setSearch('');setFilter('all');window.location.hash=next;}
 async function refresh(){const [t,c,r]=await Promise.all([request<Session[]>('tasks'),request<CasePackage[]>('cases'),request<Run[]>('runs')]);setTasks(t);setCases(c);setRuns(r.sort((a,b)=>b.startedAt.localeCompare(a.startedAt)));setConnection('');}
 useEffect(()=>{let live=true,inFlight=false;const onHash=()=>{const id=window.location.hash.slice(1);if(pages.some(p=>p.id===id)){setPage(id as Page);setSearch('');setFilter('all');}};onHash();window.addEventListener('hashchange',onHash);
 void Promise.all([request<{devices:string[]}>('bootstrap'),request<ExplorationPreferences>('settings')]).then(([b,p])=>{if(!live)return;setDevices(b.devices);setDevice(b.devices.includes(p.preferredDevice)?p.preferredDevice:b.devices[0]??'');setPreferences(p);setSavedPreferences(p);setModel(p.model);setPkg(p.packageName);setPreconditions(p.preconditions);}).catch(e=>{if(live)setError(String(e));});
 const tick=async()=>{if(inFlight)return;inFlight=true;try{if(live)await refresh();}catch(e){if(live)setConnection(String(e));}finally{inFlight=false;if(live)setLoading(false);}};void tick();const timer=setInterval(()=>void tick(),2500);return()=>{live=false;clearInterval(timer);window.removeEventListener('hashchange',onHash);};},[]);
 useEffect(()=>{setDraft(task?.candidate?structuredClone(task.candidate):null);setAnswer('');},[selected,task?.confirmation?.hash,task?.candidate?JSON.stringify(task.candidate):'']);
 async function act(fn:()=>Promise<void>){setBusy(true);setError('');setSuccess('');try{await fn();await refresh();}catch(e){setError(e instanceof Error?e.message:String(e));}finally{setBusy(false);}}
 async function refreshDevices(){const b=await request<{devices:string[]}>('bootstrap');setDevices(b.devices);if(!b.devices.includes(device))setDevice(b.devices[0]??'');}
 async function create(){await act(async()=>{const t=await request<Session>('tasks',{goal,device,packageName:pkg,model,allowModelScreenshots:consent,dataSource:data,preconditions});setSelected(t.id);await request('tasks/'+t.id+'/start',{revision:t.revision});setGoal('');setConsent(false);navigate('reports');});}
 async function freeze(){if(!task||!draft)return;await act(async()=>{const t=await request<Session>('tasks/'+task.id+'/confirm',{revision:task.revision,recipe:draft});const c=await request<CasePackage>('tasks/'+t.id+'/freeze',{revision:t.revision});setCaseId(c.id);navigate('cases');setSuccess('Case 已固化，完成独立重跑后可发布。');});}
 function openReport(t:Session){setSelected(t.id);navigate('reports');}
 const match=(text:string)=>text.toLowerCase().includes(search.toLowerCase());
 const filteredTasks=tasks.filter(t=>match(t.goal+' '+t.id)&&(filter==='all'||t.status===filter));
 const filteredCases=cases.filter(c=>(showOld||!c.compatibilityError)&&match(c.title+' '+c.id)&&(filter==='all'||c.status===filter));
 const filteredRuns=runs.filter(r=>match((cases.find(c=>c.id===r.caseId)?.title??r.caseId)+' '+r.id)&&(filter==='all'||r.status===filter));
 const settingsDirty=JSON.stringify(preferences)!==JSON.stringify(savedPreferences);
 const shortTask=(t:Session)=>t.candidate?.title??t.goal;

 const [caseTab,setCaseTab]=useState('steps'),[reportTab,setReportTab]=useState('overview');
 const primary={bg:'#63cbae',color:'#10291f',_hover:{bg:'#7cdec2'}};
 const descriptions:Record<Page,string>={tasks:'从测试目标开始，自动探索并留下可核验的证据。',reports:'查看测试结论、操作证据与待确认方案。',cases:'管理可重复执行的测试方案。',runs:'跟踪每一次独立验证与回归。',settings:'配置模型、设备和工作区偏好。'};
 const pageCount=page==='tasks'||page==='reports'?tasks.length:page==='cases'?cases.filter(c=>!c.compatibilityError).length:page==='runs'?runs.length:undefined;
 const caseRuns=currentCase?runs.filter(r=>r.caseId===currentCase.id):[];
 const taskRows=filteredTasks.map(t=><ListRow key={t.id} title={shortTask(t)} selected={selected===t.id} onClick={()=>{openReport(t);setReportTab('overview');}} meta={<StateBadge value={t.status}/>} extra={<span>{t.records.length} 步 · {date(t.createdAt)}</span>}/>);
 const caseTabs=[{id:'steps',label:'方案与断言'},{id:'runs',label:'运行记录'+(caseRuns.length?' · '+caseRuns.length:'')},{id:'files',label:'文件与产物'}];
 const reportTabs=[{id:'overview',label:'测试结论'},{id:'evidence',label:'操作证据'+(task?' · '+task.records.length:'')},...(task?.status==='report'&&draft?[{id:'freeze',label:'确认方案'}]:[])];
 const activeReportTab=reportTabs.some(t=>t.id===reportTab)?reportTab:'overview';

 const runDetails=(r:Run)=><div className={styles.detailStack}>
  <Panel title={cases.find(c=>c.id===r.caseId)?.title??'运行结果'} lead extra={<StateBadge value={r.status}/>}>
   <div className={styles.metadataTags}><span className={styles.tag}><Glyph name="clock" size={14}/>{date(r.startedAt)}</span><span className={styles.tag}>{r.mode==='verify'?'发布验证':'回归运行'}</span></div>
   <div className={styles.detailMeta}><DetailMeta label="App 结果"><StateBadge value={r.appResult}/></DetailMeta><DetailMeta label="操作步骤">{r.records.length} 步</DetailMeta><DetailMeta label="结束时间">{r.finishedAt?date(r.finishedAt):'运行中'}</DetailMeta></div>
   <div className={styles.summary}>资源清理 / {r.cleanup.ok?'已完成':'未确认'} · {r.cleanup.detail}</div>
   <Text color="fg.subtle" fontSize="2xs" fontFamily="mono" overflowWrap="anywhere">{r.id}</Text>
   {r.error&&<Notice status="error">{r.error}</Notice>}
   {r.status==='running'&&<Button size="sm" variant="subtle" colorPalette="red" alignSelf="start" disabled={busy} onClick={()=>void act(async()=>{await request('runs/'+r.id+'/stop',{});})}>停止运行</Button>}
  </Panel>
  <Records records={r.records} kind="runs" id={r.id}/>
 </div>;

 return <div className={styles.workspace}>
  <aside className={styles.sidebar} aria-label="主导航">
   <div className={styles.brand}><div className={styles.brandMark}><Glyph name="layers" size={21}/></div><div className={styles.brandText}><div className={styles.brandName}>Genesis</div><div className={styles.brandSub}>TEST WORKSPACE</div></div></div>
   <div className={styles.workspaceLabel}><span className={styles.workspaceAvatar}>W</span><span>Worldo 工作区</span></div>
   <div className={styles.navLabel}>工作台</div>
   <nav className={styles.nav} aria-label="工作区">{pages.map(p=><a key={p.id} href={'#'+p.id} className={styles.navLink} aria-current={page===p.id?'page':undefined} aria-label={p.name}><Glyph name={p.icon}/><span className={styles.navText}>{p.name}</span>{p.id!=='settings'&&<span className={styles.navCount}>{p.id==='tasks'?tasks.length:p.id==='reports'?tasks.filter(t=>t.status==='report').length:p.id==='cases'?cases.filter(c=>!c.compatibilityError).length:runs.length}</span>}</a>)}</nav>
   <div className={styles.sidebarBottom}><div className={styles.deviceStatus} data-online={devices.length>0}><i aria-hidden="true"/>{devices.length} 台设备在线</div><div className={styles.sidebarFootnote}>{activeCount?activeCount+' 项任务运行中':devices.length?'设备就绪 · 本地工作区':'连接 Android 设备以开始测试'}</div></div>
  </aside>
  <main className={styles.main}>
   <header className={styles.masthead}>
    <div><div className={styles.breadcrumb}>工作台 <Glyph name="chevron" size={10}/> {pages.find(p=>p.id===page)?.name}</div><div className={styles.pageTitleLine}><h1 className={styles.pageTitle}>{pages.find(p=>p.id===page)?.name}</h1>{pageCount!==undefined&&<span className={styles.pageCount}>{pageCount}</span>}</div><div className={styles.pageDescription}>{descriptions[page]}</div></div>
    <div className={styles.headerActions}><span className={styles.service} data-error={!!connection} data-loading={loading}><i aria-hidden="true"/>{loading?'正在连接':connection?'连接异常':'本地服务已连接'}</span><button type="button" className={styles.iconButton} aria-label="刷新工作区" disabled={busy} onClick={()=>void act(refresh)}><Glyph name="refresh" size={16}/></button>{page!=='tasks'&&page!=='settings'&&<button type="button" className={styles.newButton} onClick={()=>navigate('tasks')}><Glyph name="plus" size={15}/><span>新建测试</span></button>}</div>
   </header>
   <FeedbackToast message={error} type="error"/><FeedbackToast message={success} type="success"/>
   {connection&&<div className={styles.notice}><Notice status="error">{connection}</Notice></div>}
   {page!=='settings'&&<div className={styles.toolbar}><div className={styles.search}><Glyph name="search" size={16}/><input type="search" aria-label="搜索当前列表" placeholder={page==='cases'?'搜索 Case 名称或 ID…':page==='runs'?'搜索运行或 Case…':'搜索测试目标或 ID…'} value={search} onChange={e=>setSearch(e.target.value)}/></div>{page==='tasks'&&<span className={styles.toolbarHint}>先探索，再固化为可重复执行的 Case</span>}<div className={styles.filter}><Choice label="状态筛选" value={filter} onChange={setFilter} items={[{value:'all',label:'全部状态'},...(page==='cases'?['candidate','verified','published']:page==='runs'?['running','completed','stopped','error']:['draft','exploring','report','needs_input','stopped','error']).map(v=>({value:v,label:labels[v]??v}))]}/></div>{page==='cases'&&<Check checked={showOld} onChange={setShowOld}>历史版本</Check>}</div>}
   <div className={styles.content}>

   {page==='tasks'&&<div className={styles.taskLayout}>
    <section className={styles.taskList}><div className={styles.taskListTop}><span>最近测试</span><span>{filteredTasks.length} 条记录</span></div><div className={styles.taskListBody} aria-label="任务列表滚动区域">
     {filteredTasks.map(t=><button type="button" key={t.id} className={styles.taskOverviewRow} onClick={()=>{openReport(t);setReportTab('overview');}}><Glyph name="activity" size={19}/><div><div className={styles.taskOverviewTitle}>{shortTask(t)}</div><div className={styles.taskOverviewMeta}><span>{t.records.length} 个操作步骤</span><span>{date(t.createdAt)}</span><span>{t.model}</span></div></div><div><StateBadge value={t.status}/></div></button>)}
     {!filteredTasks.length&&<Empty>{loading?'加载任务…':'还没有测试任务，在右侧填写目标即可开始。'}</Empty>}
    </div></section>
    <aside className={styles.composer} aria-label="新建测试"><div className={styles.composerHeader}><Glyph name="spark" size={17}/>新建测试</div><div className={styles.composerBody} aria-label="新建测试表单"><div className={styles.formStack}>
     <FormField label="测试目标"><Textarea size="sm" rows={3} resize="vertical" maxH="220px" value={goal} onChange={e=>setGoal(e.target.value)} placeholder="例如：验证 MiniPhone 音乐的播放、暂停和后台恢复"/></FormField>
     <div className={styles.formGrid}><Choice label="Android 设备" value={device} onChange={setDevice} items={devices.map(d=>({value:d,label:d}))} placeholder="选择设备"/><Choice label="测试数据" value={data} onChange={v=>setData(v as typeof data)} items={[{value:'existing',label:'已有真实数据'},{value:'mock',label:'已准备好的模拟环境'}]}/></div>
     <FormField label="应用包名"><Input size="sm" value={pkg} onChange={e=>setPkg(e.target.value)}/></FormField>
     <FormField label="前提和操作范围"><Textarea size="sm" rows={2} value={preconditions} onChange={e=>setPreconditions(e.target.value)}/></FormField>
     <FormField label="本次探索模型"><Input size="sm" value={model} onChange={e=>setModel(e.target.value)}/></FormField>
     <Check checked={consent} onChange={setConsent}>允许将本次应用截图与观测发送给 Codex 模型，可能包含账号和页面内容。</Check>
     <div className={styles.formHint}>使用已安装 App，保留账号和缓存。实际测试完成后，先生成报告，再确认是否固化。</div>
    </div></div><div className={styles.composerActions}><Button size="sm" flex="1" {...primary} disabled={busy||!goal.trim()||!device||!model||!consent} loading={busy} onClick={()=>void create()}><Glyph name="runs" size={15}/>开始 AI 测试</Button><Button size="sm" variant="ghost" aria-label="刷新设备" disabled={busy} onClick={()=>void act(refreshDevices)}><Glyph name="refresh" size={15}/></Button></div></aside>
   </div>}

   {page==='reports'&&<MasterDetail label="测试报告" count={filteredTasks.length} list={taskRows}>{task?<div className={styles.detailStack}>
    <Panel title={task.candidate?.title??'测试报告'} lead extra={<StateBadge value={task.status}/>}>
     <div className={styles.metadataTags}><span className={styles.tag}><Glyph name="device" size={14}/>{task.device}</span><span className={styles.tag}>{task.packageName}</span><span className={styles.tag}>{task.model}</span></div>
     <Text color="fg.subtle" fontSize="xs">{task.identity?'Android '+task.identity.android+' · App '+task.identity.version+' · APK '+task.identity.apkSha256.slice(0,12):'环境尚未核对'}</Text>
    </Panel>
    <div><DetailTabs id="report-detail" items={reportTabs} value={activeReportTab} onChange={setReportTab}/>
     <div role="tabpanel" id="report-detail-panel" aria-labelledby={'report-detail-'+activeReportTab} className={styles.tabPanel}>
     {activeReportTab==='overview'&&<div className={styles.detailStack}>
      <Panel title="测试结论"><div className={styles.summary}>{task.goal}</div><div className={styles.stats}><div className={styles.stat}><strong>{task.records.length}</strong><span>操作步骤</span></div><div className={styles.stat}><strong>{task.records.filter(r=>r.verdict==='passed').length}</strong><span>断言通过</span></div><div className={styles.stat}><strong>{task.records.filter(r=>r.verdict==='failed').length}</strong><span>功能未通过</span></div></div>{task.report&&<div className={styles.reportResult}>{task.report}</div>}{task.error&&<Notice status="error">{task.error}</Notice>}{task.limitations.map((l,i)=><Text color="orange.300" key={i} fontSize="xs">覆盖边界 / {l}</Text>)}</Panel>
      {task.status==='exploring'&&<Button size="sm" colorPalette="red" variant="subtle" alignSelf="start" disabled={busy} onClick={()=>void act(async()=>{await request('tasks/'+task.id+'/stop',{});})}>停止测试</Button>}
      {(['needs_input','stopped','error','draft'].includes(task.status)||(task.status==='report'&&!draft))&&<Panel title="继续测试"><Text>{task.question||'补充说明后继续测试。'}</Text><Textarea size="sm" aria-label="补充说明" value={answer} onChange={e=>setAnswer(e.target.value)}/><Button size="sm" {...primary} alignSelf="start" disabled={busy} onClick={()=>void act(async()=>{await request('tasks/'+task.id+'/start',{revision:task.revision,answer});})}>继续测试</Button></Panel>}
      {task.status==='report'&&draft&&<div className={styles.actionRow}><Button size="sm" {...primary} onClick={()=>setReportTab('freeze')}>确认测试方案<Glyph name="arrow" size={14}/></Button><Button size="sm" variant="ghost" onClick={()=>setReportTab('evidence')}>查看操作证据</Button></div>}
     </div>}
     {activeReportTab==='evidence'&&<Records records={task.records} kind="tasks" id={task.id}/>}
     {activeReportTab==='freeze'&&task.status==='report'&&draft&&<Panel title="确认并固化测试方案">
      <div className={styles.formGrid}><FormField label="Case 名称"><Input size="sm" value={draft.title} onChange={e=>setDraft({...draft,title:e.target.value})}/></FormField><Choice label="场景结束检查点" value={draft.steps.at(-1)?.id??''} onChange={v=>{const steps=task.candidate?.steps??draft.steps;setDraft({...draft,steps:steps.slice(0,steps.findIndex(s=>s.id===v)+1)});}} items={(task.candidate?.steps??draft.steps).map(s=>({value:s.id,label:s.description}))}/></div>
      <FormField label="验证范围"><Textarea size="sm" rows={2} value={draft.scope} onChange={e=>setDraft({...draft,scope:e.target.value})}/></FormField><Text color="fg.muted" fontSize="xs">前提 / {draft.preconditions}</Text>
      <div>{draft.steps.map(s=><div className={styles.ruleRow} key={s.id}><span>{s.id}</span><div><Text fontSize="xs">{s.description}</Text><Text fontSize="2xs" color="fg.muted">{s.check?s.check.source+' / '+s.check.operator+' / '+s.check.expected:'导航与操作'}</Text></div></div>)}</div>
      <Choice label="结束处理" value={draft.cleanup} onChange={v=>setDraft({...draft,cleanup:v as Recipe['cleanup']})} items={[{value:'none',label:'保留最终页面和数据'},{value:'home',label:'返回 Android 桌面，保留应用数据'}]}/>
      <Text color="fg.muted" fontSize="xs">改变步骤或预期需要补测；固化后的 Case 需独立重跑验证。</Text><Button size="sm" {...primary} alignSelf="start" disabled={busy} onClick={()=>void freeze()}>确认方案并固化 Case</Button>
      <FormField label="调整或补测"><Input size="sm" placeholder="描述需要补测的内容" value={answer} onChange={e=>setAnswer(e.target.value)}/></FormField><Button size="sm" variant="outline" alignSelf="start" disabled={busy||!answer.trim()} onClick={()=>void act(async()=>{await request('tasks/'+task.id+'/start',{revision:task.revision,answer});})}>补测并更新报告</Button>
     </Panel>}
     </div>
    </div>
   </div>:<Empty>选择一份报告，查看测试结论与操作证据。</Empty>}</MasterDetail>}

   {page==='cases'&&<MasterDetail label="全部 Cases" count={filteredCases.length} list={<>{filteredCases.map(c=><ListRow key={c.id} title={c.title} selected={caseId===c.id} onClick={()=>{setCaseId(c.id);setCaseTab('steps');}} meta={<StateBadge value={c.compatibilityError?'stopped':c.status}/>} extra={<span>v{c.version} · {c.recipe.steps.length} 步</span>}/>)}{!filteredCases.length&&<Empty>没有匹配的 Case</Empty>}</>}>{currentCase?<div className={styles.detailStack}>
    <Panel title={currentCase.title} lead extra={<StateBadge value={currentCase.status}/>}>
     <div className={styles.summary}>{currentCase.recipe.scope}</div>
     <div className={styles.detailMeta}><DetailMeta label="方案版本">v{currentCase.version}</DetailMeta><DetailMeta label="执行步骤">{currentCase.recipe.steps.length} 个步骤</DetailMeta><DetailMeta label="创建时间">{date(currentCase.createdAt)}</DetailMeta></div>
     <div className={styles.actionRow}><Button size="sm" {...primary} disabled={busy||!!currentCase.compatibilityError||runs.some(r=>r.caseId===currentCase.id&&r.status==='running')} onClick={()=>void act(async()=>{const r=await request<Run>('cases/'+currentCase.id+'/run',{mode:currentCase.status==='published'?'regression':'verify'});setRunId(r.id);navigate('runs');})}><Glyph name="runs" size={15}/>{currentCase.status==='published'?'运行回归':'独立重跑验证'}</Button>
      {currentCase.status==='verified'&&!currentCase.compatibilityError&&<Button size="sm" variant="outline" disabled={busy} onClick={()=>void act(async()=>{await request('cases/'+currentCase.id+'/publish',{hash:currentCase.hash});setSuccess('Case 已发布。');})}>发布 Case</Button>}
      <Button size="sm" variant="outline" disabled={!!currentCase.compatibilityError} asChild><Link href={'/api/exploration/cases/'+currentCase.id+'/download'}><Glyph name="download" size={14}/>下载 Case 包</Link></Button><Button size="sm" variant="ghost" onClick={()=>{setSelected(currentCase.sessionId);setReportTab('overview');navigate('reports');}}>来源报告<Glyph name="chevron" size={12}/></Button>
     </div>
     {currentCase.compatibilityError&&<Notice status="warning">运行环境已变化。请从已确认报告重新固化候选并重跑，旧证据不会沿用。</Notice>}
    </Panel>
    <div><DetailTabs id="case-detail" items={caseTabs} value={caseTab} onChange={setCaseTab}/>
     <div role="tabpanel" id="case-detail-panel" aria-labelledby={'case-detail-'+caseTab} className={styles.tabPanel}>
     {caseTab==='steps'&&<div className={styles.detailStack}><Panel title="测试前提"><div className={styles.summary}>{currentCase.recipe.preconditions}</div></Panel><Panel title="固定步骤与断言"><table className={styles.dataTable}><thead><tr><th>步骤</th><th>操作</th><th>预期</th></tr></thead><tbody>{currentCase.recipe.steps.map(s=><tr key={s.id}><td>{s.id}</td><td>{s.description}</td><td>{s.check?s.check.source+' · '+s.check.operator+' · '+s.check.expected:'—'}</td></tr>)}</tbody></table></Panel><div className={styles.tag}>{currentCase.id} · {currentCase.hash.slice(0,12)}</div></div>}
     {caseTab==='runs'&&<Panel title="验证与回归记录" extra={<Text color="fg.muted" fontSize="2xs">最近三次独立验证一致后可发布</Text>}>{caseRuns.length?<div>{caseRuns.map(r=><button key={r.id} type="button" className={styles.runRow} onClick={()=>{setRunId(r.id);navigate('runs');}}><span>{date(r.startedAt)}<small>{r.mode==='verify'?'发布验证':'回归'}</small></span><span className={styles.actionRow}><StateBadge value={r.status}/><StateBadge value={r.appResult}/><Glyph name="chevron" size={13}/></span></button>)}</div>:<Empty>尚无运行记录。</Empty>}</Panel>}
     {caseTab==='files'&&<Panel title="产物清单"><div className={styles.fileGrid}>{[...Object.keys(currentCase.files),'manifest.json'].map(f=><div className={styles.fileItem} key={f}><Glyph name="report" size={16}/>{f}</div>)}</div></Panel>}
     </div>
    </div>
   </div>:<Empty>选择一个 Case，管理测试方案、独立验证与回归。</Empty>}</MasterDetail>}

   {page==='runs'&&<MasterDetail label="全部运行" count={filteredRuns.length} list={<>{filteredRuns.map(r=><ListRow key={r.id} title={cases.find(c=>c.id===r.caseId)?.title??r.caseId} selected={runId===r.id} onClick={()=>setRunId(r.id)} meta={<><StateBadge value={r.status}/><StateBadge value={r.appResult}/></>} extra={<span>{date(r.startedAt)}</span>}/>)}{!filteredRuns.length&&<Empty>没有匹配的运行记录</Empty>}</>}>{currentRun?runDetails(currentRun):<Empty>选择一次运行，查看结果、操作证据与资源清理。</Empty>}</MasterDetail>}

   {page==='settings'&&<div style={{height:'100%',display:'flex',flexDirection:'column',minHeight:0}}>
    <div className={styles.settingsScroll} aria-label="设置滚动区域"><div className={styles.settingsGrid}>
     <div className={styles.settingsColumn}><Panel title="新任务默认配置" extra={<span className={styles.state} data-tone={settingsDirty?'warning':'neutral'}>{settingsDirty?'未保存':'已保存'}</span>}>
      <p className={styles.settingsHelp}>用于后续新任务，已有任务和 Case 的配置保持独立。</p>
      <div className={styles.formGrid}><FormField label="默认探索模型"><Input size="sm" value={preferences.model} onChange={e=>setPreferences({...preferences,model:e.target.value})}/></FormField><FormField label="默认应用包名"><Input size="sm" value={preferences.packageName} onChange={e=>setPreferences({...preferences,packageName:e.target.value})}/></FormField></div>
      <Choice label="默认设备" value={preferences.preferredDevice||'auto'} onChange={v=>setPreferences({...preferences,preferredDevice:v==='auto'?'':v})} items={[{value:'auto',label:'自动选择已连接设备'},...Array.from(new Set([...devices,...(preferences.preferredDevice?[preferences.preferredDevice]:[])])).map(d=>({value:d,label:d+(devices.includes(d)?'':' · 离线')}))]}/>
      <FormField label="默认测试前提"><Textarea size="sm" rows={4} value={preferences.preconditions} onChange={e=>setPreferences({...preferences,preconditions:e.target.value})}/></FormField>
     </Panel><Panel title="外观"><div className={styles.detailMeta}><DetailMeta label="主题">深色 · 青绿</DetailMeta><DetailMeta label="界面密度">紧凑</DetailMeta><DetailMeta label="日志字体">Consolas / Sarasa Mono SC</DetailMeta></div></Panel></div>
     <div className={styles.settingsColumn}><Panel title="设备管理" extra={<Button size="xs" variant="ghost" disabled={busy} onClick={()=>void act(refreshDevices)}><Glyph name="refresh" size={13}/>刷新设备</Button>}>
      <Choice label="操作设备" value={device} onChange={setDevice} items={devices.map(d=>({value:d,label:d}))}/>
      <p className={styles.settingsHelp}>服务中断后可核对占用。正在执行的任务不会被强行释放。</p>
      <Button size="sm" variant="outline" alignSelf="start" disabled={busy||!device} onClick={()=>void act(async()=>{await request('recover-device',{device});setSuccess('已核对并解除中断进程的设备占用。');})}>核对并解除中断占用</Button>
     </Panel><Panel title="执行规则"><div>{[['探索','AI 根据实际观测决定下一步，由平台操作设备并留证。'],['固化','确认后的操作生成脚本、断言、定位和来源记录。'],['发布','最近三次独立验证结果一致，覆盖完整且清理成功。'],['回归','固定脚本执行，不调用 AI 修改步骤或预期。'],['授权','每次新任务单独确认截图授权。']].map(([k,v])=><div className={styles.ruleRow} key={k}><strong>{k}</strong><span>{v}</span></div>)}</div></Panel></div>
    </div></div>
    <div className={styles.settingsActions}><Button size="sm" {...primary} disabled={busy||!settingsDirty} onClick={()=>void act(async()=>{const p=await request<ExplorationPreferences>('settings',preferences);setPreferences(p);setSavedPreferences(p);setModel(p.model);setPkg(p.packageName);setPreconditions(p.preconditions);if(p.preferredDevice&&devices.includes(p.preferredDevice))setDevice(p.preferredDevice);setSuccess('默认配置已保存，后续新任务将使用此配置。');})}>保存设置</Button><Button size="sm" variant="ghost" disabled={!settingsDirty||busy} onClick={()=>setPreferences({...savedPreferences})}>撤销修改</Button><span className={styles.settingsHelp}>{settingsDirty?'存在未保存的修改':'配置已同步'}</span></div>
   </div>}

   </div>
   <footer className={styles.footer}><span>{loading?'正在加载…':tasks.length+' 测试 · '+cases.filter(c=>!c.compatibilityError).length+' Cases · '+runs.length+' 次运行'}</span><span><Glyph name="device" size={11}/>Android · 本地工作区</span></footer>
  </main>
 </div>;
}
