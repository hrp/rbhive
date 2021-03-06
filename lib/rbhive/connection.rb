# suppress warnings
old_verbose, $VERBOSE = $VERBOSE, nil
# require thrift autogenerated files
require File.join(File.dirname(__FILE__), *%w[.. thrift thrift_hive])
# restore warnings
$VERBOSE = old_verbose

module RBHive
  def connect(server, port=10_000)
    connection = RBHive::Connection.new(server, port)
    ret = nil
    begin
      connection.open
      ret = yield(connection)
    ensure
      connection.close
      ret
    end
  end
  module_function :connect
  
  class StdOutLogger
    %w(fatal error warn info debug).each do |level| 
      define_method level.to_sym do |message|
        STDOUT.puts(message)
     end
   end
  end
  
  class Connection
    attr_reader :client
    
    def initialize(server, port=10_000, logger=StdOutLogger.new)
      @socket = Thrift::Socket.new(server, port)
      @transport = Thrift::BufferedTransport.new(@socket)
      @protocol = Thrift::BinaryProtocol.new(@transport)
      @client = ThriftHive::Client.new(@protocol)
      @logger = logger
      @logger.info("Connecting to #{server} on port #{port}")
    end
    
    def open
      @transport.open
    end
    
    def close
      @transport.close
    end
    
    def client
      @client
    end
    
    def execute(query)
      @logger.info("Executing Hive Query: #{query}")
      client.execute(query)
    end
    
    def priority=(priority)
      set("mapred.job.priority", priority)
    end
    
    def queue=(queue)
      set("mapred.job.queue.name", queue)
    end
    
    def set(name,value)
      @logger.info("Setting #{name}=#{value}")
      client.execute("SET #{name}=#{value}")
    end
    
    def fetch(query)
      execute(query)
      ResultSet.new(client.fetchAll, query)
    end
    
    def fetch_in_batch(query, batch_size=100)
      execute(query)
      until (next_batch = client.fetchN(batch_size)).empty?
        yield ResultSet.new(next_batch)
      end
    end
    
    def first(query)
      execute(query)
      ResultSet.new([client.fetchOne])
    end
    
    def create_table(schema)
      execute(schema.create_table_statement)
    end
    
    def drop_table(name)
      name = name.name if name.is_a?(TableSchema)
      execute("DROP TABLE `#{name}`")
    end
    
    def replace_columns(schema)
      execute(schema.replace_columns_statement)
    end
    
    def add_columns(schema)
      execute(schema.add_columns_statement)
    end
    
    def method_missing(meth, *args)
      client.send(meth, *args)
    end
  end
  
  class ResultSet < Array
    attr_reader :query
    def initialize(rows, query=nil)
      @query = query
      super(rows.map {|r| r.split("\t") })
    end
    
    def to_csv(out_file=nil)
      output(",", out_file)
    end
    
    def to_tsv(out_file=nil)
      output("\t", out_file)
    end
    
    private
    
    def output(sep, out_file)
      sv = self.map { |r| r.join(sep) }.join("\n")
      return sv if out_file.nil?
      ::CSV.open(out_file, 'w') do |csv|
        self.each do |s|
          csv << s
        end
      end
    end
  end
end
