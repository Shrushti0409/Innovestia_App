import mongoose from 'mongoose';
const schema = new mongoose.Schema({owner: {type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true}, profile: {type: mongoose.Schema.Types.ObjectId, ref: 'Profile', required: true}}, {timestamps: true});
schema.index({owner: 1, profile: 1}, {unique: true});
export default mongoose.model('SavedProfile', schema);
