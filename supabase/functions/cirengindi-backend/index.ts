// @ts-nocheck
import { createClient } from 'npm:@supabase/supabase-js@2';
const SB_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PUBLIC = Deno.env.get('SUPABASE_ANON_KEY')!;
const admin = createClient(SB_URL, SERVICE, {auth:{autoRefreshToken:false,persistSession:false}});
const client = createClient(SB_URL, PUBLIC, {auth:{autoRefreshToken:false,persistSession:false}});
const cors = {'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'apikey,authorization,content-type,x-client-info','Access-Control-Allow-Methods':'POST,OPTIONS','Content-Type':'application/json; charset=utf-8'};
const reply=(value,status=200)=>new Response(JSON.stringify(value),{status,headers:cors});
const err=(message,status=400)=>reply({error:message,message},status);
function check(d){if(d.error)throw new Error(d.error.message);return d.data}
async function list(table,query='*',opts={}){let r=admin.from(table).select(query);if(opts.eq)for(const [key,v] of Object.entries(opts.eq))r=r.eq(key,v);if(opts.order)r=r.order(opts.order,{ascending:!!opts.asc});if(opts.limit)r=r.limit(opts.limit);return check(await r)}
async function member(req){const token=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');if(!token)throw new Error('AUTH_REQUIRED');const {data,error}=await admin.auth.getUser(token);if(error||!data.user)throw new Error('AUTH_REQUIRED');const p=check(await admin.from('member_profiles').select('*').eq('user_id',data.user.id).maybeSingle());if(!p||p.status!=='active')throw new Error('AUTH_REQUIRED');return {user:data.user,profile:p};}
async function staff(req){
 const token=req.headers.get('Authorization')?.replace(/^Bearer\s+/i,'');if(!token)throw new Error('AUTH_REQUIRED');
 const {data,error}=await admin.auth.getUser(token);if(error||!data.user)throw new Error('AUTH_REQUIRED');
 let s=check(await admin.from('staff_profiles').select('*').eq('user_id',data.user.id).eq('active',true).maybeSingle());
 // One-time onboarding of the designated proprietor after verifiable email confirmation.
 // Requiring a confirmation-sent event avoids trusting auto-confirmed signups.
 const u=data.user;
 const sent=u.confirmation_sent_at,confirmed=u.email_confirmed_at;
 if(!s && String(u.email||'').toLowerCase()==='rizkyhidayat8999@gmail.com'
  && sent && confirmed && Date.parse(confirmed)>=Date.parse(sent)){
   s=check(await admin.from('staff_profiles').upsert({user_id:u.id,full_name:'Owner Cireng Indi',role:'owner',active:true},{onConflict:'user_id'}).select('*').single());
 }
 if(!s)throw new Error('STAFF_REQUIRED');return {user:u,staff:s};
}
async function points(id){let rows=await list('ci_point_ledger','delta',{eq:{member_id:id}});return rows.reduce((n,x)=>n+Number(x.delta),0)}
async function cart(id){const ct=check(await admin.from('ci_carts').select('id').eq('member_id',id).maybeSingle());if(!ct)return {items:[],subtotal:0};const lines=await list('ci_cart_items','id,variant_id,quantity',{eq:{cart_id:ct.id}});const variants=lines.length?check(await admin.from('ci_product_variants').select('*,product:ci_products(*)').in('id',lines.map(x=>x.variant_id))):[];const items=lines.map(i=>({...i,variant:variants.find(v=>v.id===i.variant_id)}));return {items,subtotal:items.reduce((n,i)=>n+Number(i.variant?.price||0)*i.quantity,0)};}
async function orderRows(rows){
 if(!rows?.length)return [];
 const ids=rows.map(x=>x.id),courierIds=[...new Set(rows.map(x=>x.courier_id).filter(Boolean))];
 const items=check(await admin.from('ci_order_items').select('*').in('order_id',ids));
 const payments=check(await admin.from('ci_payments').select('*').in('order_id',ids));
 const couriers=courierIds.length?check(await admin.from('ci_couriers').select('id,name,flat_fee').in('id',courierIds)):[];
 const contacts=courierIds.length?check(await admin.from('ci_courier_contacts').select('courier_id,whatsapp').in('courier_id',courierIds)):[];
 const proofUrls=new Map();
 for(const p of payments.filter(p=>p.proof_storage_path)){
   const signed=await admin.storage.from('ci-payment-proofs').createSignedUrl(p.proof_storage_path,600);
   if(!signed.error)proofUrls.set(p.order_id,signed.data.signedUrl);
 }
 return rows.map(o=>{
  const pay=payments.find(x=>x.order_id===o.id), courier=couriers.find(x=>x.id===o.courier_id);
  return {...o,items:items.filter(i=>i.order_id===o.id),
   payment:pay?{id:pay.id,method:pay.method,status:pay.status,amount:pay.amount,review_note:pay.review_note,bank_snapshot:pay.bank_snapshot,proof_submitted_at:pay.proof_submitted_at,proof_url:proofUrls.get(o.id)||null}:null,
   courier:courier?{id:courier.id,name:courier.name,whatsapp:contacts.find(x=>x.courier_id===courier.id)?.whatsapp||null}:null};
 });
}
async function paymentSettings(){
 const x=check(await admin.from('ci_app_settings').select('value').eq('key','bank_transfer').maybeSingle())?.value||{};
 return {enabled:!!(x.enabled&&x.bank_name&&x.account_number&&x.account_holder),bank_name:String(x.bank_name||''),account_number:String(x.account_number||''),account_holder:String(x.account_holder||'')};
}

async function authApi(b){const a=b.action;if(a==='register'){
 const username=String(b.username||'').trim().toLowerCase(),email=String(b.email||'').trim().toLowerCase(),name=String(b.fullName||'').trim(),password=String(b.password||'');
 if(!/^[a-z0-9._]{3,24}$/.test(username)||!/^\S+@\S+\.\S+$/.test(email)||name.length<2)return err('INVALID_INPUT');
 if(password.length<8||!/[a-z]/i.test(password)||!/[0-9]/.test(password))return err('WEAK_PASSWORD');
 if((await list('member_profiles','user_id',{eq:{username}})).length)return err('USERNAME_TAKEN');
 if((await list('member_profiles','user_id',{eq:{email}})).length)return err('EMAIL_TAKEN');
 const created=await client.auth.signUp({email,password,options:{data:{full_name:name},emailRedirectTo:'https://cirengindi.com/reset-password'}});
 if(created.error)return err(created.error.message,400);
 const id=created.data.user.id;
 const profile={user_id:id,username,email,full_name:name,phone:b.phone||null,referral_code:('CI'+id.replaceAll('-','').slice(0,9)).toUpperCase()};
 const ins=await admin.from('member_profiles').insert(profile).select('*').single();if(ins.error){return err(ins.error.message)};
 if(!created.data.session)return reply({member:ins.data,pendingVerification:true});
 return reply({member:ins.data,session:created.data.session});
 }
 if(a==='login'){
 const username=String(b.username||'').trim().toLowerCase();
 const p=check(await admin.from('member_profiles').select('*').ilike('username',username).maybeSingle());
 if(!p)return err('INVALID_CREDENTIALS',401);
 const logged=await client.auth.signInWithPassword({email:p.email,password:String(b.password||'')});
 if(logged.error)return err('INVALID_CREDENTIALS',401);
 return reply({member:p,session:logged.data.session});
 }
 if(a==='forgot_password'){
 const email=String(b.email||'').trim();if(!email)return err('EMAIL_REQUIRED');
 const p=check(await admin.from('member_profiles').select('email').ilike('email',email).maybeSingle());
 if(p)await client.auth.resetPasswordForEmail(email,{redirectTo:'https://cirengindi.com/reset-password'});
 return reply({ok:true});
 }
 return err('UNKNOWN_ACTION',404);
}
async function mobile(req,b){
 const a=b.action;
 if(a==='bootstrap')return reply({categories:await list('ci_categories','*',{eq:{active:true},order:'sort_order'}),products:await list('ci_products','*',{eq:{active:true},order:'sort_order'}),variants:await list('ci_product_variants','*',{eq:{active:true},order:'sort_order'}),banners:await list('ci_banners','*',{eq:{active:true},order:'sort_order'}),couriers:await list('ci_couriers','*',{eq:{active:true},order:'sort_order'}),bank_transfer:await paymentSettings()});
 const {user,profile}=await member(req),uid=user.id;
 if(a==='me')return reply({profile,points:await points(uid)});
 if(a==='addresses')return reply({addresses:await list('ci_addresses','*',{eq:{member_id:uid},order:'created_at'})});
 if(a==='address_create'){
  for(const field of ['recipient_name','phone','address_line','city','province'])if(!String(b[field]||'').trim())return err('ADDRESS_INCOMPLETE');
  const attrs={member_id:uid,label:String(b.label||'Rumah').slice(0,50),recipient_name:String(b.recipient_name).slice(0,100),phone:String(b.phone).slice(0,30),address_line:String(b.address_line).slice(0,500),city:String(b.city).slice(0,100),province:String(b.province).slice(0,100),postal_code:String(b.postal_code||'').slice(0,16)};
  const d=check(await admin.from('ci_addresses').insert(attrs).select('*').single());return reply({address:d});
 }
 if(a==='address_default'){
  const addr=check(await admin.from('ci_addresses').select('id').eq('id',b.id).eq('member_id',uid).maybeSingle());if(!addr)return err('ADDRESS_NOT_FOUND');
  check(await admin.from('ci_addresses').update({is_default:false}).eq('member_id',uid));check(await admin.from('ci_addresses').update({is_default:true}).eq('id',addr.id).eq('member_id',uid));return reply({ok:true});
 }
 if(a==='cart')return reply(await cart(uid));
 if(a==='cart_set'){
  const quantity=Number(b.quantity),variant=check(await admin.from('ci_product_variants').select('*').eq('id',b.variant_id).eq('active',true).maybeSingle());
  if(!variant||!Number.isInteger(quantity)||quantity<0||quantity>100)return err('INVALID_CART_ITEM');
  const carts=check(await admin.from('ci_carts').select('id').eq('member_id',uid).maybeSingle());if(!carts)return err('CART_NOT_FOUND');
  if(quantity>variant.stock)return err('INSUFFICIENT_STOCK');
  if(quantity===0)check(await admin.from('ci_cart_items').delete().eq('cart_id',carts.id).eq('variant_id',variant.id));
  else check(await admin.from('ci_cart_items').upsert({cart_id:carts.id,variant_id:variant.id,quantity},{onConflict:'cart_id,variant_id'}));
  return reply(await cart(uid));
 }
 if(a==='checkout_cod'||a==='checkout'){
  const method=a==='checkout_cod'?'cod':String(b.payment_method||'cod');
  // The SQL procedure performs stock validation, deductions, and order/payment creation atomically.
  const d=check(await admin.rpc('ci_checkout',{p_member_id:uid,p_fulfillment:String(b.fulfillment_type||'pickup'),p_payment_method:method,p_address_id:b.address_id||null,p_notes:b.notes||null}));
  return reply({order:d});
 }
 if(a==='payment_proof_upload'){
  const order=check(await admin.from('ci_orders').select('id,status').eq('id',b.order_id).eq('member_id',uid).maybeSingle());
  if(!order||order.status==='cancelled'||order.status==='completed')return err('ORDER_NOT_FOUND',404);
  const pay=check(await admin.from('ci_payments').select('*').eq('order_id',order.id).single());
  if(pay.method!=='transfer'||!['pending','rejected'].includes(pay.status))return err('PROOF_NOT_ALLOWED');
  const mime=String(b.mime||''),encoded=String(b.base64||'');
  if(!['image/png','image/jpeg','image/webp'].includes(mime)||!encoded||encoded.length>4_200_000||!/^[A-Za-z0-9+/]+={0,2}$/.test(encoded))return err('INVALID_IMAGE');
  let bytes;try{bytes=Uint8Array.from(atob(encoded),c=>c.charCodeAt(0))}catch{return err('INVALID_IMAGE')}
  if(!bytes.length||bytes.length>3_145_728)return err('IMAGE_TOO_LARGE');
  const jpeg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
  const png=bytes[0]===137&&bytes[1]===80&&bytes[2]===78&&bytes[3]===71;
  const webp=bytes[0]===82&&bytes[1]===73&&bytes[2]===70&&bytes[3]===70&&bytes[8]===87&&bytes[9]===69&&bytes[10]===66&&bytes[11]===80;
  if(!(mime==='image/jpeg'&&jpeg||mime==='image/png'&&png||mime==='image/webp'&&webp))return err('INVALID_IMAGE');
  const ext=mime==='image/jpeg'?'jpg':mime==='image/png'?'png':'webp';
  const path=uid+'/'+order.id+'/'+crypto.randomUUID()+'.'+ext;
  const saved=await admin.storage.from('ci-payment-proofs').upload(path,bytes,{contentType:mime,upsert:false});
  if(saved.error)throw saved.error;
  const previous=pay.proof_storage_path;
  const upd=check(await admin.from('ci_payments').update({status:'submitted',proof_storage_path:path,proof_file_type:mime,proof_submitted_at:new Date().toISOString(),review_note:null,reviewed_at:null,reviewed_by:null}).eq('id',pay.id).in('status',['pending','rejected']).select('id').maybeSingle());
  if(!upd){await admin.storage.from('ci-payment-proofs').remove([path]);return err('PROOF_NOT_ALLOWED')}
  if(previous)await admin.storage.from('ci-payment-proofs').remove([previous]);
  return reply({ok:true,status:'submitted'});
 }
 if(a==='orders'){
  const orders=await list('ci_orders','*',{eq:{member_id:uid},order:'created_at',limit:100});return reply({orders:await orderRows(orders)});
 }
 if(a==='order_cancel'){
  const o=check(await admin.from('ci_orders').select('*').eq('id',b.id).eq('member_id',uid).maybeSingle());if(!o||o.status!=='pending')return err('INVALID_STATUS_TRANSITION');
  check(await admin.rpc('ci_cancel_order_safe',{p_order_id:o.id,p_member_id:uid}));
  return reply({ok:true});
 }
 if(a==='rewards')return reply({rewards:await list('ci_rewards','*',{eq:{active:true},order:'sort_order'}),points:await points(uid)});
 if(a==='reward_redeem'){
  const r=check(await admin.from('ci_rewards').select('*').eq('id',b.id).eq('active',true).maybeSingle());if(!r||r.stock<=0)return err('REWARD_UNAVAILABLE');if(await points(uid)<r.points_cost)return err('INSUFFICIENT_POINTS');
  // Limited to one redemption at a time to avoid concurrent duplicate spending.
  const pending=await list('ci_reward_redemptions','id',{eq:{member_id:uid,status:'pending'}});if(pending.length)return err('REDEMPTION_PENDING');
  const d=check(await admin.from('ci_reward_redemptions').insert({member_id:uid,reward_id:r.id,points_spent:r.points_cost}).select('*').single());
  check(await admin.from('ci_point_ledger').insert({member_id:uid,delta:-r.points_cost,reason:'reward_redeemed',redemption_id:d.id}));return reply({redemption:d});
 }
 if(a==='change_password'){
  if(typeof b.password!=='string'||b.password.length<8)return err('WEAK_PASSWORD');const x=await admin.auth.admin.updateUserById(uid,{password:b.password});if(x.error)throw x.error;return reply({ok:true});
 }
 if(a==='logout')return reply({ok:true});
 return err('UNKNOWN_ACTION',404);
}
async function owner(req,b){
 const {user,staff:s}=await staff(req);const a=b.action;
 if(a==='me')return reply({staff:s,email:user.email});
 if(a==='dashboard'){
  const today=new Date().toISOString().slice(0,10);
  const orders=await list('ci_orders','*',{order:'created_at',limit:50});const prod=await list('ci_products','id',{eq:{active:true}}),vs=await list('ci_product_variants','stock',{eq:{active:true}}),ms=await list('member_profiles','user_id',{eq:{status:'active'}}),reds=await list('ci_reward_redemptions','status',{eq:{status:'pending'}});
  const todayOrders=orders.filter(x=>String(x.created_at).startsWith(today));
  return reply({today_orders:todayOrders.length,today_completed_revenue:todayOrders.filter(x=>x.status==='completed').reduce((n,x)=>n+x.total,0),pending_processing:orders.filter(x=>['pending','processing'].includes(x.status)).length,low_stock:vs.filter(x=>x.stock<=5).length,active_products:prod.length,active_members:ms.length,pending_redemptions:reds.length,latest_orders:orders.slice(0,10)});
 }
 if(a==='orders')return reply({orders:await orderRows(await list('ci_orders','*',{order:'created_at',limit:Math.min(200,Number(b.limit)||150)}))});
 if(a==='products')return reply({products:await list('ci_products','*',{order:'sort_order'}),variants:await list('ci_product_variants','*',{order:'sort_order'})});
 if(a==='members')return reply({members:await list('member_profiles','*',{order:'created_at',limit:Math.min(200,Number(b.limit)||200)})});
 if(a==='rewards')return reply({rewards:await list('ci_rewards','*',{order:'sort_order'}),redemptions:await list('ci_reward_redemptions','*',{order:'created_at'})});
 if(a==='settings'){
  const couriers=await list('ci_couriers','*',{order:'sort_order'});
  const contacts=await list('ci_courier_contacts','*');
  return reply({banners:await list('ci_banners','*',{order:'sort_order'}),couriers:couriers.map(c=>({...c,whatsapp:contacts.find(x=>x.courier_id===c.id)?.whatsapp||''})),bank_transfer:await paymentSettings()});
 }
 if(a==='set_bank_transfer'){
  if(s.role!=='owner')return err('OWNER_REQUIRED',403);
  const bank_name=String(b.bank_name||'').trim().slice(0,70);
  const account_number=String(b.account_number||'').replace(/\s/g,'').slice(0,40);
  const account_holder=String(b.account_holder||'').trim().slice(0,100);
  const enabled=!!b.enabled;
  if(enabled&&(!bank_name||!account_holder||!/^[-0-9]{5,40}$/.test(account_number)))return err('INVALID_BANK_DETAILS');
  check(await admin.from('ci_app_settings').upsert({key:'bank_transfer',value:{enabled,bank_name,account_number,account_holder}},{onConflict:'key'}));
  return reply({ok:true,bank_transfer:await paymentSettings()});
 }
 if(a==='assign_courier'){
  const updated=check(await admin.rpc('ci_assign_courier_safe',{p_order_id:b.id,p_courier_id:b.courier_id}));
  return reply({ok:true,order:updated});
 }
 if(a==='payment_review'){
  const decision=String(b.decision||'');if(!['approve','reject'].includes(decision))return err('INVALID_PAYMENT_DECISION');
  const o=check(await admin.from('ci_orders').select('id,status').eq('id',b.id).maybeSingle());
  if(!o||o.status==='cancelled'||o.status==='completed')return err('ORDER_NOT_FOUND');
  const payment=check(await admin.from('ci_payments').select('*').eq('order_id',o.id).maybeSingle());
  if(!payment||payment.method!=='transfer'||payment.status!=='submitted'||!payment.proof_storage_path)return err('PAYMENT_NOT_SUBMITTED');
  const note=String(b.note||'').trim().slice(0,250);
  if(decision==='reject'&&!note)return err('REJECTION_REASON_REQUIRED');
  const update=check(await admin.from('ci_payments').update({status:decision==='approve'?'paid':'rejected',review_note:note||null,reviewed_at:new Date().toISOString(),reviewed_by:user.id,paid_at:decision==='approve'?new Date().toISOString():null}).eq('id',payment.id).eq('status','submitted').select('id').maybeSingle());
  if(!update)return err('PAYMENT_ALREADY_REVIEWED');
  return reply({ok:true});
 }
 if(a==='confirm_cod_payment'){
  const o=check(await admin.from('ci_orders').select('id,status').eq('id',b.id).maybeSingle());
  if(!o||o.status==='cancelled')return err('ORDER_NOT_FOUND');
  const p=check(await admin.from('ci_payments').select('*').eq('order_id',o.id).single());
  if(p.method!=='cod')return err('NOT_COD');
  check(await admin.from('ci_payments').update({status:'paid',paid_at:new Date().toISOString(),reviewed_by:user.id,reviewed_at:new Date().toISOString()}).eq('id',p.id).eq('status','pending'));
  return reply({ok:true});
 }
 if(a==='set_stock'){
  if(!Number.isInteger(Number(b.stock))||Number(b.stock)<0)return err('INVALID_STOCK');check(await admin.from('ci_product_variants').update({stock:Number(b.stock)}).eq('id',b.id));return reply({ok:true});
 }
 if(a==='set_product_active'){
  check(await admin.from('ci_products').update({active:!!b.active}).eq('id',b.id));return reply({ok:true});
 }
 if(a==='update_variant'){
  if(Number(b.price)<0||Number(b.stock)<0||!Number.isInteger(Number(b.stock)))return err('INVALID_STOCK');
  check(await admin.from('ci_product_variants').update({name:String(b.name||'').slice(0,100),price:Number(b.price),stock:Number(b.stock),active:!!b.active}).eq('id',b.id));return reply({ok:true});
 }
 if(a==='update_banner'){
  check(await admin.from('ci_banners').update({title:String(b.title||'').slice(0,100),subtitle:String(b.subtitle||'').slice(0,500),active:!!b.active,kind:b.kind||null,sort_order:Number(b.sort_order)||0}).eq('id',b.id));return reply({ok:true});
 }
 if(a==='update_courier'){
  if(Number(b.flat_fee)<0||!Number.isInteger(Number(b.flat_fee)))return err('INVALID_FEE');
  check(await admin.from('ci_couriers').update({name:String(b.name||'').slice(0,100),flat_fee:Number(b.flat_fee),active:!!b.active,sort_order:Number(b.sort_order)||0}).eq('id',b.id));
  if(b.whatsapp!==undefined){const wa=String(b.whatsapp||'').replace(/[^0-9]/g,'');if(wa&&!/^62[0-9]{8,14}$/.test(wa))return err('INVALID_WA');check(await admin.from('ci_courier_contacts').upsert({courier_id:b.id,whatsapp:wa||null},{onConflict:'courier_id'}));}
  return reply({ok:true});
 }
 if(a==='set_reward_stock'){
  if(Number(b.stock)<0||!Number.isInteger(Number(b.stock)))return err('INVALID_STOCK');check(await admin.from('ci_rewards').update({stock:Number(b.stock)}).eq('id',b.id));return reply({ok:true});
 }
 if(a==='set_redemption_status'){
  const red=check(await admin.from('ci_reward_redemptions').select('*').eq('id',b.id).maybeSingle());if(!red||red.status!=='pending'||!['fulfilled','cancelled'].includes(b.status))return err('INVALID_STATUS_TRANSITION');
  check(await admin.from('ci_reward_redemptions').update({status:b.status,fulfilled_at:b.status==='fulfilled'?new Date().toISOString():null}).eq('id',b.id));
  if(b.status==='cancelled')check(await admin.from('ci_point_ledger').insert({member_id:red.member_id,delta:red.points_spent,reason:'reward_refund',redemption_id:red.id}));
  return reply({ok:true});
 }
 if(a==='set_order_status'){
  const o=check(await admin.from('ci_orders').select('*').eq('id',b.id).maybeSingle());if(!o)return err('ORDER_NOT_FOUND');
  const next={pending:['processing','cancelled'],processing:o.fulfillment_type==='pickup'?['completed','cancelled']:['shipped','cancelled'],shipped:['completed'],completed:[],cancelled:[]};
  if(!(next[o.status]||[]).includes(b.status))return err('INVALID_STATUS_TRANSITION');
  const pay=check(await admin.from('ci_payments').select('method,status').eq('order_id',o.id).single());
  if(pay.method==='transfer' && b.status!=='cancelled' && pay.status!=='paid')return err('PAYMENT_NOT_CONFIRMED');
  if(b.status==='shipped'&&o.fulfillment_type==='delivery'&&!o.courier_id)return err('COURIER_REQUIRED');
  if(b.status==='cancelled'){
   check(await admin.rpc('ci_cancel_order_safe',{p_order_id:o.id,p_member_id:null}));return reply({ok:true});
  }
  const update={status:b.status, ...(b.status==='completed'?{completed_at:new Date().toISOString()}:{}),...(b.status==='cancelled'?{cancelled_at:new Date().toISOString()}: {})};
  check(await admin.from('ci_orders').update(update).eq('id',o.id).eq('status',o.status));
  if(b.status==='completed'){
   const ledger=check(await admin.from('ci_point_ledger').select('id').eq('order_id',o.id).eq('reason','order_completed').maybeSingle());
   const amount=Math.floor(Number(o.subtotal)/10000);
   if(!ledger&&amount>0)check(await admin.from('ci_point_ledger').insert({member_id:o.member_id,delta:amount,reason:'order_completed',order_id:o.id}));
   if(pay.method==='cod')check(await admin.from('ci_payments').update({status:'paid',paid_at:new Date().toISOString()}).eq('order_id',o.id).eq('status','pending')); 
  }
  return reply({ok:true});
 }
 if(a==='logout')return reply({ok:true});
 return err('UNKNOWN_ACTION',404);
}
Deno.serve(async req=>{
 if(req.method==='OPTIONS')return new Response(null,{status:204,headers:cors});
 if(req.method!=='POST')return err('METHOD_NOT_ALLOWED',405);
 try{
  const endpoint=new URL(req.url).pathname.split('/').filter(Boolean).at(-1);
  const b=await req.json();if(typeof b!=='object'||!b)return err('INVALID_REQUEST');
  if(endpoint==='member-auth')return await authApi(b);
  if(endpoint==='cirengindi-mobile-api')return await mobile(req,b);
  if(endpoint==='cirengindi-owner-api')return await owner(req,b);
  return err('UNKNOWN_ENDPOINT',404);
 }catch(e){const msg=String(e?.message||e);console.error('API error:',msg);return err(msg, msg==='AUTH_REQUIRED'||msg==='STAFF_REQUIRED'?401:400)}
});