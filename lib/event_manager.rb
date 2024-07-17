require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'


def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0')[0..4]
end

def clean_phone_number(number)
  temp = ''
  number.each_char do |s|
    begin
      temp << s[/\d+/]
    rescue
      temp << ''
    end
  end
  if temp.size == 10
    temp
  elsif temp.size == 11 && temp[0].to_i == 1
    temp[1..10]
  else
    'wrong number'
  end
end

def peak_time_reg(regtime)
  hour, minute = regtime.split(':')
  hour
end

def peak_reg_day(regday)
  regday = regday.split('/').map(&:to_i)
  Date.new(regday[2], regday[0], regday[1]).wday
end

def legislators_by_zipcode(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'
  begin
    legislators = civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
     'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end



def save_thank_you_letter(id, form_letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"
  File.open(filename, 'w') do |file|
    file.puts form_letter
  end
end

puts 'EventManager initialized.'

contents = CSV.open(
  'event_attendees.csv',
  headers: true,
  header_converters: :symbol
)

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter


temp = []
temp_regday = []

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  homephone = row[:homephone]
  regdate = row[:regdate]

  phonenumber = clean_phone_number(homephone)
  regtime = regdate.split(' ')[1]
  regday = regdate.split(' ')[0]
  regday = peak_reg_day(regday)
  temp_regday << regday
  peaktime = peak_time_reg(regtime)
  temp << peaktime

  zipcode = clean_zipcode(row[:zipcode])
  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  save_thank_you_letter(id, form_letter)
  #puts "#{id} #{name} #{phonenumber} #{regtime}"
end

temp = temp.map(&:to_i)
freq = temp.inject(Hash.new(0)) {|h,v| h[v]+= 1; h}
max = freq.values.max
most_registred_hours = Hash[freq.select { |k, v| v == max} ]
puts "Most registered hours are #{most_registred_hours.keys.join(', ')}"


freq_day = temp_regday.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
max = freq_day.values.max
most_registred_day = Hash[freq_day.select { |k, v| v == max} ]
day = most_registred_day.keys.join.to_i
days_of_the_week = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
puts "Most registered day is #{days_of_the_week[day]}"
