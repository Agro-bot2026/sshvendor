const fs=require('fs'), axios=require('axios');
const token=fs.readFileSync(__dirname+'/.license','utf8').trim();
const api=fs.readFileSync(__dirname+'/.apibase','utf8').trim();
const BOT_VERSION="1.0.0";
module.exports=async function guard(){
  try{
    const r=await axios.get(`${api}/api/validate/${token}?v=${BOT_VERSION}`,{timeout:10000});
    if(!r.data.ok){console.error('❌ Licencia no válida:',r.data.reason);process.exit(1);}
    console.log('✅ Licencia válida');
  }catch(e){console.error('❌ No se pudo validar la licencia:',e.message);process.exit(1);}
};
