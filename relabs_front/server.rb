require 'sinatra'

get '/' do
  content_type :html
  File.open('app/views/index.html')
end
