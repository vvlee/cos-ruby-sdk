require 'bundler/setup'
require 'cos'

client = COS::Client.new(app_id:'10016219',secret_id:'AKIDMWHN7IrmIr6OgVomLFhdXgitZEEIZrDl',secret_key:'e6k4QPIWnn9FUslwWQ1Inm0Jv7aU9Otw')

# options = {threads: 10}
#
# retry_times = 10
# begin
#   s = client.api.upload_slice('test4', 'AxureRP-Pro-Setup.1426488743.dmg', '/Users/Raymond/Downloads/AxureRP-Pro-Setup.1426488743.dmg', options) do |p|
#     p "Progress: #{(p*100).round(2)}%"
#   end
# rescue => e
#   if retry_times > 0
#     retry_times -= 1
#     # logger
#     retry
#   else
#     raise e
#   end
# end
#
# p s
# client.api.create_folder('/123/321/')
# client.api.list('test4', '33', pattern: :file_only, num: 2, context: '')
# client.api.update('test4/333/', '我是业务')
# p client.api.stat('test4/AxureRP-Pro-Setup.1426488743.dmg')
# client.api.delete('test3/')

bucket = client.bucket('costest')
# p bucket.stat('test1/').name
# res = bucket.list('/test4/', num: 2)
res = bucket.count

# res.each do |r|
#   p r.name
# end

p res