io=
  if __filename.slice(-7) is '.coffee'
    require './src'
  else
    require './lib'

unless module.parent?
  io.listen 59798,->
    console.log 'Listen to http://localhost:59798'

module.exports= io
