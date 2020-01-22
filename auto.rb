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


  update_name_and_email(r)

  set_password(r)

  reset_mfa

  change_group

  add_alias(r)
end

# done
def go_to_profile(r)
  @browser.navigate.to "https://thekey.me/cas-management/users/admin"
  element = @browser.find_element(css: 'input#email')
  element.send_keys r[1]
  find_button(@browser, 'Search').click

  check_for_multiple_results

  find_button(@browser, 'Edit').click
end

# done
def check_for_multiple_results
  count = @browser.find_elements(class: "main-row").count
  if count > 1
    raise "more than 1 result"
  end
end

def update_name_and_email(row)

end

def set_password(row)

end

def reset_mfa

end

def change_group

end

def add_alias(row)

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