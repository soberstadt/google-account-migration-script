require "selenium-webdriver"

require '~/key_login.rb'
require_relative 'helpers.rb'

def setup_browser
  @browser = Selenium::WebDriver.for :chrome
  @browser.navigate.to "https://thekey.me/cas-management/users/admin"

  login(@browser)

  wait = Selenium::WebDriver::Wait.new(timeout: 200) # seconds
  wait.until { @browser.find_element(css: 'input#email') }
end

def connect_to_drive_file
  # how?
  @file = nil
end

def loop_over_rows(rows)
  rows.each { |r| run_cleanup(r) }
end

def run_cleanup(r)
  # 1 check if email needs to change
  # 2 set temp pazwrd
  # 3 reset MFA
  # 4 change OU to Taiwan
  # 5 update first name last name
  # 6 add aliases"
end

def run
  connect_to_drive_file
  setup_browser
  loop_over_rows(@file.rows)
end

begin
  run
rescue StandardError => error
  p error
  sleep 20
  @browser&.quit
end
