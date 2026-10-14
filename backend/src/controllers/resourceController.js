import Profile from '../models/Profile.js';
import InvestmentRequest from '../models/InvestmentRequest.js';
import Conversation from '../models/Conversation.js';
import Message from '../models/Message.js';
import Notification from '../models/Notification.js';
import User from '../models/User.js';
import SavedProfile from '../models/SavedProfile.js';
import {mkdir, writeFile, readFile, unlink} from 'node:fs/promises';
import path from 'node:path';
import mongoose from 'mongoose';
export async function listProfiles(req, res) { const type = req.query.type || (req.user.role === 'STARTUP' ? 'INVESTOR' : 'STARTUP'); if (!['STARTUP','INVESTOR'].includes(type) || type === req.user.role) return res.status(422).json({message:'Invalid discovery type.'}); const query = {type, user: {$ne: req.user.id}}; if (req.query.q) { const q = String(req.query.q).slice(0,100).replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); query.$or = ['name','industry','location','businessStage','description','preferences'].map(field => ({[field]: {$regex:q,$options:'i'}})); } for (const field of ['industry','location','businessStage']) if (req.query[field]) query[field] = String(req.query[field]).slice(0,100); const limit = Math.min(Math.max(Number(req.query.limit) || 20,1),50); const items = await Profile.find(query).limit(limit).sort('-createdAt').lean(); res.json({data: {items}}); }
export async function myProfile(req, res) { const profile = await Profile.findOne({user: req.user.id}); res.json({data: {profile}}); }
export async function updateProfile(req, res) {
  const allowed = [
    'name', 'location', 'industry', 'businessStage', 'description', 'website',
    'fundingRequired', 'fundingRaised', 'investmentRangeMin',
    'investmentRangeMax', 'preferences',
  ];
  const update = Object.fromEntries(Object.entries(req.body || {}).filter(([key]) => allowed.includes(key)));
  if (typeof update.name !== 'string' || !update.name.trim()) {
    return res.status(422).json({message: 'Profile name is required.'});
  }
  update.name = update.name.trim();
  const stringLimits = {
    name: 100,
    location: 120,
    industry: 120,
    businessStage: 120,
    description: 2000,
    website: 500,
  };
  for (const [field, limit] of Object.entries(stringLimits)) {
    if (update[field] === undefined) continue;
    if (typeof update[field] !== 'string') {
      return res.status(422).json({message: `${field} must be text.`});
    }
    update[field] = update[field].trim();
    if (update[field].length > limit) {
      return res.status(422).json({message: `${field} is too long.`});
    }
  }
  if (update.website) {
    try {
      const website = new URL(update.website);
      if (!['http:', 'https:'].includes(website.protocol)) throw new Error();
    } catch {
      return res.status(422).json({message: 'Website must be a valid HTTP or HTTPS URL.'});
    }
  }
  const unset = [];
  for (const field of ['fundingRequired','fundingRaised','investmentRangeMin','investmentRangeMax']) {
    if (update[field] === undefined) continue;
    if (update[field] === null || update[field] === '') {
      delete update[field];
      unset.push(field);
      continue;
    }
    if (!Number.isFinite(Number(update[field])) || Number(update[field]) < 0) {
      return res.status(422).json({message: `${field} must be a non-negative number.`});
    }
    update[field] = Number(update[field]);
  }
  if (update.investmentRangeMin !== undefined &&
      update.investmentRangeMax !== undefined &&
      update.investmentRangeMin > update.investmentRangeMax) {
    return res.status(422).json({message: 'Minimum investment must not exceed maximum investment.'});
  }
  const changes = {
    $set: update,
    $setOnInsert: {user: req.user.id, type: req.user.role},
  };
  if (unset.length) changes.$unset = Object.fromEntries(unset.map(field => [field, 1]));
  const profile = await Profile.findOneAndUpdate(
    {user: req.user.id},
    changes,
    {new: true, upsert: true, runValidators: true, setDefaultsOnInsert: true},
  );
  res.json({data: {profile}});
}
export async function createInterest(req, res) { if (req.user.role !== 'INVESTOR') return res.status(403).json({message: 'Only investors can express interest.'}); const startup = await User.findById(req.params.startupId); if (!startup || startup.role !== 'STARTUP') return res.status(404).json({message: 'Startup not found.'}); const exists = await InvestmentRequest.findOne({startup: startup.id, investor: req.user.id, status: 'PENDING'}); if (exists) return res.status(409).json({message: 'You already have a pending request for this startup.'}); const request = await InvestmentRequest.create({startup: startup.id, investor: req.user.id, message: req.body.message}); await Notification.create({recipient: startup.id, title: 'New investment interest', body: `${req.user.name} expressed interest in your startup.`, type: 'INVESTMENT_REQUEST', data: {requestId: request.id}}); res.status(201).json({data: {request}}); }
export async function listRequests(req, res) { const query = req.user.role === 'STARTUP' ? {startup: req.user.id} : req.user.role === 'INVESTOR' ? {investor: req.user.id} : {}; const items = await InvestmentRequest.find(query).populate('startup investor', 'name email').sort('-createdAt'); res.json({data: {items}}); }
export async function updateRequest(req, res) { const request = await InvestmentRequest.findById(req.params.id); if (!request) return res.status(404).json({message: 'Request not found.'}); if (request.startup.toString() !== req.user.id && req.user.role !== 'ADMIN') return res.status(403).json({message: 'Permission denied.'}); if (!['ACCEPTED','REJECTED'].includes(req.body.status)) return res.status(422).json({message: 'Invalid request status.'}); if(request.status!=='PENDING')return res.status(409).json({message:'This request has already been decided.'}); request.status = req.body.status; await request.save(); await Notification.create({recipient: request.investor, title: 'Investment request updated', body: `Your request was ${request.status.toLowerCase()}.`, type: 'INVESTMENT_REQUEST', data: {requestId: request.id}}); res.json({data: {request}}); }
export async function searchChatUsers(req,res) { if (!['STARTUP','INVESTOR'].includes(req.user.role)) return res.status(403).json({message:'Chat search is unavailable for this account.'}); const role=req.user.role==='STARTUP'?'INVESTOR':'STARTUP'; const q=String(req.query.q||'').trim().slice(0,100); const users=await User.find({_id:{$ne:req.user.id},role,name:{$regex:q.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),$options:'i'}}).select('_id name role').limit(20).lean(); const profiles=await Profile.find({user:{$in:users.map(u=>u._id)}}).select('user industry location').lean(); const byUser=new Map(profiles.map(p=>[String(p.user),p])); res.json({data:{items:users.map(u=>({...u,profile:byUser.get(String(u._id))||null}))}}); }
export async function startConversation(req,res) { if(typeof req.body.userId!=='string'||!mongoose.isValidObjectId(req.body.userId))return res.status(422).json({message:'A valid member ID is required.'});const other=await User.findOne({_id:req.body.userId,role:req.user.role==='STARTUP'?'INVESTOR':'STARTUP'}).select('_id'); if(!other) return res.status(404).json({message:'Eligible member not found.'}); const ids=[req.user.id,other.id].map(String).sort(); const pairKey=ids.join(':'); let item=await Conversation.findOne({$or:[{pairKey},{participants:{$all:ids,$size:2}}]}); if(!item){try{item=await Conversation.create({participants:ids,pairKey});}catch(error){if(error.code!==11000)throw error;item=await Conversation.findOne({$or:[{pairKey},{participants:{$all:ids,$size:2}}]});}}else if(!item.pairKey){item.pairKey=pairKey;try{await item.save();}catch(error){if(error.code!==11000)throw error;item=await Conversation.findOne({pairKey});}} await item.populate('participants','name role'); res.status(200).json({data:{item}}); }
export async function listConversations(req, res) { const items = await Conversation.find({participants: req.user.id}).populate('participants', 'name role').sort('-lastMessageAt').lean(); const ids=items.map(x=>x._id); const [last,unread]=await Promise.all([Message.aggregate([{$match:{conversation:{$in:ids}}},{$sort:{createdAt:-1}},{$group:{_id:'$conversation',message:{$first:'$$ROOT'}}}]),Message.aggregate([{$match:{conversation:{$in:ids},sender:{$ne:req.user._id},readBy:{$ne:req.user._id}}},{$group:{_id:'$conversation',count:{$sum:1}}}])]); const lm=new Map(last.map(x=>[String(x._id),x.message])); const unreadMap=new Map(unread.map(x=>[String(x._id),x.count])); const senders=[...new Set(last.map(x=>String(x.message.sender)))]; const users=await User.find({_id:{$in:senders}}).select('name').lean(); const names=new Map(users.map(x=>[String(x._id),x.name])); res.json({data:{items:items.map(x=>({...x,unreadCount:unreadMap.get(String(x._id))||0,lastMessage:lm.has(String(x._id))?{...lm.get(String(x._id)),sender:{name:names.get(String(lm.get(String(x._id)).sender))||'Member'}}:null}))}}); }
export async function messages(req, res) { const conversation = await Conversation.findOne({_id: req.params.id, participants: req.user.id}); if (!conversation) return res.status(404).json({message: 'Conversation not found.'}); await Message.updateMany({conversation:conversation.id,sender:{$ne:req.user._id},readBy:{$ne:req.user._id}},{$addToSet:{readBy:req.user._id}}); const items = await Message.find({conversation: conversation.id}).populate('sender', 'name').sort('createdAt'); res.json({data: {items}}); }
export async function sendMessage(req, res) { const conversation = await Conversation.findOne({_id: req.params.id, participants: req.user.id}); if (!conversation) return res.status(404).json({message: 'Conversation not found.'}); if (typeof req.body.body!=='string' || !req.body.body.trim()) return res.status(422).json({message: 'Message cannot be empty.'}); if(req.body.body.length>4000) return res.status(422).json({message:'Message is too long.'}); const message = await Message.create({conversation: conversation.id, sender: req.user.id, body: req.body.body.trim(), readBy: [req.user.id]}); conversation.lastMessageAt = new Date(); await conversation.save(); const recipients = conversation.participants.filter(id => id.toString() !== req.user.id); for(const recipient of recipients){const exists=await Notification.exists({recipient,type:'MESSAGE','data.conversationId':conversation.id,createdAt:{$gte:new Date(Date.now()-30000)}});if(!exists) await Notification.create({recipient,title:'New message',body:`You have a new message from ${req.user.name}.`,type:'MESSAGE',data:{conversationId:conversation.id}});} res.status(201).json({data: {message}}); }
export async function savedProfiles(req,res){const saved=await SavedProfile.find({owner:req.user.id}).sort('-createdAt').populate({path:'profile',match:{},select:'-user'}).lean(); res.json({data:{items:saved.filter(x=>x.profile).map(x=>({...x.profile,savedAt:x.createdAt}))}});}
export async function saveProfile(req,res){if(!mongoose.isValidObjectId(req.params.profileId))return res.status(404).json({message:'Profile not found.'});const profile=await Profile.findById(req.params.profileId);if(!profile||profile.user.toString()===req.user.id)return res.status(404).json({message:'Profile not found.'});if(profile.type===req.user.role)return res.status(403).json({message:'You can only save profiles of the other account type.'});await SavedProfile.updateOne({owner:req.user.id,profile:profile.id},{$setOnInsert:{owner:req.user.id,profile:profile.id}},{upsert:true});res.status(200).json({data:{saved:true}});}
export async function unsaveProfile(req,res){await SavedProfile.deleteOne({owner:req.user.id,profile:req.params.profileId});res.status(204).end();}
const deckDir=()=>path.resolve(process.env.PITCH_DECK_DIR||path.join(process.cwd(),'private_uploads','pitch_decks'));
export async function uploadPitchDeck(req,res){if(req.user.role!=='STARTUP')return res.status(403).json({message:'Only startups can upload a pitch deck.'});const bytes=req.body;if(!Buffer.isBuffer(bytes)||bytes.length<8||bytes.subarray(0,5).toString()!=='%PDF-')return res.status(422).json({message:'Upload a valid PDF file.'});const title=String(req.query.title||'').trim().slice(0,120);const summary=String(req.query.summary||'').trim().slice(0,500);const description=String(req.query.description||'').trim().slice(0,2000);if(!title)return res.status(422).json({message:'Pitch deck title is required.'});const profile=await Profile.findOne({user:req.user.id});if(!profile)return res.status(404).json({message:'Create your startup profile before uploading a pitch deck.'});const dir=deckDir();await mkdir(dir,{recursive:true,mode:0o700});const filename=`${req.user.id}.pdf`;await writeFile(path.join(dir,filename),bytes,{mode:0o600});profile.pitch={url:filename,filename,title,summary,description,size:bytes.length,updatedAt:new Date()};await profile.save();res.status(200).json({data:{pitch:profile.pitch}});}
export async function deletePitchDeck(req,res){const profile=await Profile.findOne({user:req.user.id});if(!profile?.pitch?.url)return res.status(404).json({message:'Pitch deck not found.'});try{await unlink(path.join(deckDir(),path.basename(profile.pitch.url)));}catch(error){if(error.code!=='ENOENT')throw error;}profile.pitch=undefined;await profile.save();res.status(204).end();}
export async function downloadPitchDeck(req,res){if(!mongoose.isValidObjectId(req.params.profileId))return res.status(404).json({message:'Pitch deck not found.'});const profile=await Profile.findById(req.params.profileId);if(!profile?.pitch?.url)return res.status(404).json({message:'Pitch deck not found.'});if(profile.user.toString()!==req.user.id&&!(profile.type==='STARTUP'&&req.user.role==='INVESTOR'))return res.status(403).json({message:'You are not allowed to access this pitch deck.'});try{const bytes=await readFile(path.join(deckDir(),path.basename(profile.pitch.url)));res.set({'Content-Type':'application/pdf','Content-Disposition':`attachment; filename="${path.basename(profile.pitch.filename||'pitch-deck.pdf')}"`,'Content-Length':bytes.length,'Cache-Control':'private, no-store'});res.send(bytes);}catch(error){if(error.code==='ENOENT')return res.status(404).json({message:'Pitch deck file is unavailable.'});throw error;}}
export async function notifications(req, res) { const items = await Notification.find({recipient: req.user.id}).sort('-createdAt').limit(100); res.json({data: {items}}); }
export async function unreadCount(req,res){const count=await Notification.countDocuments({recipient:req.user.id,readAt:null});res.json({data:{count}});}
export async function dashboardSummary(req,res){const role=req.user.role;if(role==='ADMIN'){const [users,startups,pending]=await Promise.all([User.countDocuments(),User.countDocuments({role:'STARTUP'}),InvestmentRequest.countDocuments({status:'PENDING'})]);return res.json({data:{items:[{label:'Users',value:users},{label:'Startups',value:startups},{label:'Pending',value:pending}]}});}const [profile,requests,messages,unread]=await Promise.all([Profile.findOne({user:req.user.id}).select('_id'),InvestmentRequest.countDocuments(role==='STARTUP'?{startup:req.user.id}:{investor:req.user.id}),Conversation.countDocuments({participants:req.user.id}),Notification.countDocuments({recipient:req.user.id,readAt:null})]);const items=role==='STARTUP'?[{label:'Profile',value:profile?1:0},{label:'Requests',value:requests},{label:'Unread alerts',value:unread}]:[{label:'Requests',value:requests},{label:'Conversations',value:messages},{label:'Unread alerts',value:unread}];res.json({data:{items}});}
export async function readNotification(req, res) { const item = await Notification.findOneAndUpdate({_id: req.params.id, recipient: req.user.id}, {readAt: new Date()}, {new: true}); if (!item) return res.status(404).json({message: 'Notification not found.'}); res.json({data: {item}}); }
export async function readAll(req, res) { await Notification.updateMany({recipient: req.user.id, readAt: null}, {readAt: new Date()}); res.status(204).end(); }
