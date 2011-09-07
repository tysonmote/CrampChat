require "rubygems"
require "bundler"
Bundler.setup( :default, :example )

require 'cramp'
require 'http_router'
require 'erb'
require 'em-hiredis'

Cramp::Websocket.backend = :rainbows

module CrampChat
  class HomeAction < Cramp::Action
    self.transport = :chunked
    
    @@template = ERB.new( File.read( File.join( File.dirname(__FILE__), 'index.html.erb' ) ) )
    
    def start
      render @@template.result( binding )
      finish
    end
  end

  class SocketAction < Cramp::Websocket
    on_data :received_data
    
    def received_data( data )
      subscribe
      publish( data )
    end
    
    def subscribe
      return if @sub
      @sub = EM::Hiredis.connect( "redis://localhost:6379" )
      @sub.subscribe( 'chat' )
      @sub.on(:message) {|channel, message| render( message ) }
    end
    
    def publish(message)
      @pub ||= EM::Hiredis.connect( "redis://localhost:6379" )
      @pub.publish( 'chat', message )
    end
  end
end

routes = HttpRouter.new do
  add( '/' ).to( CrampChat::HomeAction )
  add( '/socket' ).to( CrampChat::SocketAction )
end

run routes
