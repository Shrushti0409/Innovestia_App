import mongoose from 'mongoose';
const schema = new mongoose.Schema({participants: [{type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true}], pairKey: {type:String, unique:true, sparse:true}, lastMessageAt: Date}, {timestamps: true}); schema.index({participants: 1, lastMessageAt: -1}); export default mongoose.model('Conversation', schema);
