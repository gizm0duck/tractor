$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rubygems'
require 'tractor'
require 'faker'

Tractor.connectdb
Tractor.flushdb

class Person < Tractor::Model::Base
  attribute :id
  attribute :first_name, :index => true
  attribute :last_name, :index => true
  attribute :awesome, :type => :boolean, :index => true
  attribute :company_id, :index => true
end

class Company < Tractor::Model::Base
  association :people, Person
  
  attribute :id
  attribute :name
end

10.times do |i|
  Company.create(:id => i+1, :name => Faker::Company.name)
end

puts "Companies created successfully"

10.times do |i|
  Person.create(
    :id => i+1,
    :first_name => Faker::Name.first_name,
    :last_name => Faker::Name.last_name, 
    :awesome => rand(2)==0,
    :company_id => rand(Company.count)+1)
end

puts "Employees created successfully"

puts "# of dirty objects: #{Tractor.redis.scard("Tractor::Model::Dirty:all")}"

20.times do
  obj = Tractor.redis.spop("Tractor::Model::Dirty:all")
  puts "Background syncinng dirty object: #{obj}"
end

puts "# of dirty objects: #{Tractor.redis.scard("Tractor::Model::Dirty:all")}"

puts "updating company with id 1"

c = Company.find_by_id(1)
puts "Company name: #{c.name}"
c.name = "Jelly Copter Inc."
c.save
puts "New Company name: #{c.name}"

puts "# of dirty objects: #{Tractor.redis.scard("Tractor::Model::Dirty:all")}"
