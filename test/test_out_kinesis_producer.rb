#
#  Copyright 2014-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#  Licensed under the Amazon Software License (the "License").
#  You may not use this file except in compliance with the License.
#  A copy of the License is located at
#
#  http://aws.amazon.com/asl/
#
#  or in the "license" file accompanying this file. This file is distributed
#  on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
#  express or implied. See the License for the specific language governing
#  permissions and limitations under the License.

require 'fluent/test'
require 'fluent/plugin/out_kinesis_producer'

require 'test/unit/rr'
require 'dummy_server'

class KinesisProducerOutputTest < Test::Unit::TestCase
  def setup
    ENV['AWS_REGION'] = 'ap-northeast-1'
    ENV['AWS_ACCESS_KEY_ID'] = 'AAAAAAAAAAAAAAAAAAAA'
    ENV['AWS_SECRET_ACCESS_KEY'] = 'ffffffffffffffffffffffffffffffffffffffff'
    Fluent::Test.setup
    @server = DummyServer.start
  end

  def teardown
    ENV.delete('AWS_REGION')
    ENV.delete('AWS_ACCESS_KEY_ID')
    ENV.delete('AWS_SECRET_ACCESS_KEY')
    @server.clear
  end

  def default_config
    %[
      stream_name test-stream
      log_level error

      <kinesis_producer>
        custom_endpoint localhost
        port #{@server.port}
        verify_certificate false
        log_level error
      </kinesis_producer>
    ]
  end

  def create_driver(conf = default_config)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::KinesisProducerOutput) do
    end.configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal 'test-stream', d.instance.stream_name
    assert_equal 'ap-northeast-1', d.instance.region
    assert_equal 'localhost',   d.instance.kinesis_producer.custom_endpoint
    assert_equal @server.port,  d.instance.kinesis_producer.port
    assert_equal false,         d.instance.kinesis_producer.verify_certificate
  end

  def test_region
    d = create_driver(default_config + "region us-west-2")
    assert_equal 'us-west-2', d.instance.region
  end

  data(
    'json' => ['json', '{"a":1,"b":2}'],
    'ltsv' => ['ltsv', "a:1\tb:2"],
  )
  def test_format(data)
    formatter, expected = data
    d = create_driver(default_config + "formatter #{formatter}")
    d.emit({"a"=>1,"b"=>2})
    d.run
    assert_equal expected+"\n", @server.records.first
  end

  def test_record_count
    d = create_driver
    count = 200
    count.times do
      d.emit({"a"=>1})
    end

    d.run

    assert_equal count, @server.records.size
    assert @server.failed_count > 0
    assert @server.error_count > 0
  end
end