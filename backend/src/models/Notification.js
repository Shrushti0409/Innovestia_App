import mongoose from 'mongoose';
const schema = new mongoose.Schema({recipient: {type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true}, title: {type: String, required: true}, body: {type: String, required: true}, type: String, readAt: Date, data: mongoose.Schema.Types.Mixed}, {timestamps: true}); export default mongoose.model('Notification', schema);
