require 'spec_helper'
require 'csv'

describe RBHive::ResultSet, "#to_csv" do
    it "outputs valid CSV" do
      data = %w'"0" 1 2 3 4 5'
      rows = [ data.join("\t") ]
      rs = RBHive::ResultSet.new(rows)
      filename = 'test_csv'
      rs.to_csv(filename)
      c = CSV.read( filename )
      c.should == [data]
    end
end
