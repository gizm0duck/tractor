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


100.times do |i|
  Company.create(:id => i+1, :name => Faker::Company.name)
end

10000.times do |i|
  Person.create(
    :id => i+1,
    :first_name => Faker::Name.first_name,
    :last_name => Faker::Name.last_name, 
    :awesome => rand(2)==0,
    :company_id => rand(Company.count)+1)
end

Company.all.each do |company|
  t1 = Time.now
  employees = company.people.all
  t2 = Time.now
  puts "Company #{company.id} has #{employees.size} employees and it took #{t2-t1} seconds to retrieve them all"
end
