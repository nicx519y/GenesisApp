'use client';
import {useMemo,type ReactNode} from 'react';
import {Accordion,Box,Checkbox,Field,Flex,Image,Link,Portal,Select,Stack,Text,createListCollection} from '@chakra-ui/react';
import type {StepRecord} from '../../../service/src/exploration/model';
import {Glyph} from './exploration-layout';
import styles from './exploration-console.module.css';

export const labels:Record<string,string>={draft:'待开始',exploring:'测试中',needs_input:'待补充',report:'已生成报告',stopped:'已停止',error:'执行受阻',candidate:'待验证',verified:'可发布',published:'已发布',running:'运行中',completed:'已完成',passed:'通过',failed:'功能未通过',unknown:'无法判定',unobserved:'已操作'};
export function StateBadge({value}:{value:string}){
 const tone=['passed','published','verified'].includes(value)?'success':['error','failed'].includes(value)?'error':['running','exploring'].includes(value)?'active':['candidate','needs_input'].includes(value)?'warning':value==='report'?'info':'neutral';
 return <span className={styles.state} data-tone={tone}><i aria-hidden="true"/>{labels[value]??value}</span>;
}
export function Choice({label,value,items,onChange,placeholder='请选择',disabled=false}:{label:string;value:string;items:{label:string;value:string}[];onChange:(value:string)=>void;placeholder?:string;disabled?:boolean}){
 const collection=useMemo(()=>createListCollection({items}),[items]);
 return <Select.Root size="sm" collection={collection} value={value?[value]:[]} onValueChange={e=>onChange(e.value[0]??'')} disabled={disabled} minW="0">
  <Select.HiddenSelect/><Select.Label fontSize="xs" fontWeight="normal" color="fg.muted">{label}</Select.Label>
  <Select.Control><Select.Trigger bg="#192126" borderColor="#2a373f" rounded="md" _hover={{bg:"#202c32"}}><Select.ValueText placeholder={placeholder}/></Select.Trigger><Select.IndicatorGroup><Select.Indicator/></Select.IndicatorGroup></Select.Control>
  <Portal><Select.Positioner><Select.Content bg="#182126" color="#d5e2e8" borderWidth="1px" borderColor="#33434c" maxH="280px" fontSize="xs">{items.map(item=><Select.Item item={item} key={item.value} overflowWrap="anywhere"><Select.ItemText>{item.label}</Select.ItemText><Select.ItemIndicator/></Select.Item>)}</Select.Content></Select.Positioner></Portal>
 </Select.Root>;
}
export function Check({children,checked,onChange}:{children:ReactNode;checked:boolean;onChange:(value:boolean)=>void}){
 return <Checkbox.Root size="sm" checked={checked} onCheckedChange={e=>onChange(e.checked===true)} alignItems="flex-start"><Checkbox.HiddenInput/><Checkbox.Control mt="0.5"><Checkbox.Indicator/></Checkbox.Control><Checkbox.Label fontSize="xs" lineHeight="1.7">{children}</Checkbox.Label></Checkbox.Root>;
}
export function FormField({label,children}:{label:string;children:ReactNode}){
 return <Field.Root minW="0"><Field.Label fontSize="xs" color="fg.muted" fontWeight="normal">{label}</Field.Label>{children}</Field.Root>;
}
export function Panel({title,children,extra,tone='blue',lead=false}:{title:string;children:ReactNode;extra?:ReactNode;tone?:'blue'|'teal'|'violet'|'amber';lead?:boolean}){
 return <section className={styles.section+(lead?' '+styles.sectionLead:'')} data-content-section={tone}><div className={styles.sectionHeading}><h2>{title}</h2>{extra}</div><div className={styles.sectionBody}>{children}</div></section>;
}
export function Empty({children}:{children:ReactNode}){
 return <div className={styles.empty}><Glyph name="layers" size={28}/><span>{children}</span></div>;
}
export const date=(value:string)=>new Date(value).toLocaleString('zh-CN',{month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit',hour12:false});
export function Records({records,kind,id}:{records:StepRecord[];kind:'tasks'|'runs';id:string}){
 return <Panel title={'操作与证据 · '+records.length+' 步'}>{!records.length?<Text color="fg.muted">等待操作记录。</Text>:<Accordion.Root multiple size="sm" variant="outline">{records.map(r=><Accordion.Item key={r.id} value={r.id} borderColor="#26353e">
  <Accordion.ItemTrigger className={styles.recordTrigger} gap="3" px="3" py="3" bg="transparent" _hover={{bg:"#1b282e"}} _expanded={{bg:"#1d2c32"}}><Text color="fg.subtle" w="6" fontFamily="mono">{r.id}</Text><StateBadge value={r.verdict}/><Text flex="1" textAlign="left" fontSize="xs">{r.description}</Text><Accordion.ItemIndicator/></Accordion.ItemTrigger>
  <Accordion.ItemContent><Accordion.ItemBody px="3"><Stack gap="3"><Text color="fg.muted" lineHeight="1.8">{r.reason}</Text>{r.check&&<Box bg="#172329" p="3" borderRadius="md"><Text fontSize="xs">预期 / {r.check.source} · {r.check.operator} · {r.check.expected}</Text><Text color="fg.muted" mt="1" fontSize="xs">实际 / {r.samples.map(s=>s.value).join(' → ')||'无观测'}</Text></Box>}
  <Flex gap="4" wrap="wrap">{[r.before,r.after].map((s,i)=><Box key={s.id+i} minW="0"><Link href={'/api/exploration/evidence/'+kind+'/'+id+'/'+s.screenshot} target="_blank" rel="noreferrer"><Image src={'/api/exploration/evidence/'+kind+'/'+id+'/'+s.screenshot} alt={i?'操作后':'操作前'} h="240px" maxW="180px" objectFit="contain" borderRadius="md" loading="lazy"/></Link><Text color="fg.muted" fontSize="2xs" mt="2">{i?'操作后':'操作前'} · {s.audio}</Text></Box>)}</Flex>
  {r.after.warnings.map((w,i)=><Text color="orange.300" key={i}>{w}</Text>)}</Stack></Accordion.ItemBody></Accordion.ItemContent>
 </Accordion.Item>)}</Accordion.Root>}</Panel>;
}
