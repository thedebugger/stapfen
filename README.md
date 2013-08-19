# Stapfen

Stapfen is a simple gem to make writing stand-alone STOMP workers easier.


## Usage

(Examples can be found in the `examples/` directory)


Consider the following `myworker.rb` file:

    class MyWorker < Stapfen::Worker
      configure do
        {:hosts => [
          {
            :host => 'localhost',
            :port => 61613,
            :login => 'guest',
            :passcode => 'guest',
            :ssl => false
          }
        ]}
      end

      consume 'thequeue', :dead_letter_queue => '/queue/dlq',
                          :max_redeliveries => 0 do |message|
        data = expensive_computation(message.body)
        persist(data)
      end
    end

    MyWorker.run!


The value returned from the `configure` block is expected to be a valid
`Stomp::Client` [connection
hash](https://github.com/stompgem/stomp#hash-login-example-usage-this-is-the-recommended-login-technique).

It is also important to note that the `consume` block will be invoked inside an
**instance** of `MyWorker` and will execute inside its own `Thread`, so take
care when accessing other shared resources.

The consume block accepts the usual
[Stomp::Client](https://github.com/stompgem/stomp) subscription headers, as well
as :dead_letter_queue and :max\_redeliveries.  If either of the latter two is
present, the consumer will unreceive any messages for which the block returns
false; after :max\_redeliveries, it will send the message to :dead_letter_queue.
`consume` blocks without these headers will fail silently rather than unreceive.

## Installation

Add this line to your application's Gemfile:

    gem 'stapfen'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install stapfen

