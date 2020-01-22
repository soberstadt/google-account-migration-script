require "selenium-webdriver"

require '~/key_login.rb'
require_relative 'helpers.rb'
require 'google_drive'

def setup_browser
  @browser = Selenium::WebDriver.for :chrome
  @browser.navigate.to "https://thekey.me/cas-management/users/admin"

  login(@browser)

  wait = Selenium::WebDriver::Wait.new(timeout: 200) # seconds
  wait.until { @browser.find_element(css: 'input#email') }
end

def connect_to_drive_file
  # how?
  session = GoogleDrive::Session.from_config("config.json")
  ws = session.spreadsheet_by_key("1uYK_WjqDnQi4l-ldRUbF-yXhNw3Ok6uYuztJBuriWnk").worksheets[0]
  @headers = ws.rows.first.map(&:strip)
  @file = ws
end

def loop_over_rows(rows)
  rows[0..0].each { |r| run_cleanup(r) }
end

def run_cleanup(r)
  go_to_profile(r)

  # 1 check if email needs to change
  # 2 set temp pazwrd
  # 3 reset MFA
  # 4 change OU to Taiwan
  # 5 update first name last name
  # 6 add aliases"
end

def go_to_profile(r)
  @browser.navigate.to "https://thekey.me/cas-management/users/admin"
  element = @browser.find_element(css: 'input#email')
  element.send_keys r[1]
  find_button(@browser, 'Search').click

  check_for_multiple_results

  find_button(@browser, 'Edit').click
end

def check_for_multiple_results
  
end

def run
  connect_to_drive_file
  setup_browser
  loop_over_rows(@file.rows[2..154])
end

begin
  run
  sleep 10
rescue StandardError => error
  p error
  sleep 20
  @browser&.quit
end
