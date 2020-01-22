require "selenium-webdriver"

require '~/key_login.rb'
require_relative 'helpers.rb'
require 'google_drive'

$change_email_allowed = true
$dry_run = true

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
  ws = session.spreadsheet_by_key("1uYK_WjqDnQi4l-ldRUbF-yXhNw3Ok6uYuztJBuriWnk").worksheets[1]
  @headers = ws.rows.first.map(&:strip)
  @file = ws
end

def loop_over_rows(rows)
  rows[0..0].each { |r| run_cleanup(r) }
end

def run_cleanup(r)
  go_to_profile(r)

  update_name_and_email(r)

  go_to_profile(r)

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

  if count == 0
    raise "person not found"
  end
end

# done
def update_name_and_email(row)
  first_name = row[4]
  preferred_name = row[7]
  last_name = row[5]

  @browser.find_element(id: 'firstName').clear
  @browser.find_element(id: 'firstName').send_keys(first_name)

  if preferred_name != ''
    @browser.find_element(id: 'preferredName').clear
    @browser.find_element(id: 'preferredName').send_keys(preferred_name)
  end

  @browser.find_element(id: 'lastName').clear
  @browser.find_element(id: 'lastName').send_keys(last_name)

  if $change_email_allowed
    @browser.find_element(id: 'email').clear
    @browser.find_element(id: 'email').send_keys(row[2])
  end

  return if $dry_run
  @browser.find_element(css: '[name="_eventId_save"]').click
  # wait a half second for page to save
  sleep 0.5
end

# done
def set_password(row)
  @browser.find_element(css: '[data-target="#changePasswordCollapsible"]').click
  @browser.find_element(id: 'password').clear
  @browser.find_element(id: 'password').send_keys(row[3])

  return if $dry_run
  @browser.find_element(css: '[name="_eventId_updatePassword"]').click
  # wait a half second for page to save
  sleep 0.5
end

# done
def reset_mfa
  @browser.find_element(css: '[data-target="#mfaCollapsible"]').click

  mfa_enabled = @browser.find_elements(css: '[name="_eventId_resetMfaSecret"]').count > 0
  return unless mfa_enabled


  return if $dry_run
  sleep 0.5
  @browser.find_element(css: '[name="_eventId_resetMfaSecret"]').click
  # wait a half second for page to save
  sleep 0.5
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
  p 'success! 🎉'
  sleep 10
rescue StandardError => error
  p error
  sleep 20
  @browser&.quit
end
