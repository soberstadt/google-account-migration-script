require 'selenium-webdriver'
require 'google_drive'
require 'pry-byebug'

LOGIN_HELPER_FILE = '~/key_login.rb'
SPREADSHEET_KEY = "1uYK_WjqDnQi4l-ldRUbF-yXhNw3Ok6uYuztJBuriWnk"
SHEET_INDEX = 1
G_GROUP_NAME = 'Ghana'

# use the actual row numbers (the first row is 1, not 0)
START_ROW_NUMBER=3
END_ROW_NUMBER=154

EXISTING_EMAIL_COLUMN_INDEX=10
DESIRED_EMAIL_COLUMN_INDEX=2
FIRST_NAME_COLUMN_INDEX=4
PREFERRED_NAME_COLUMN_INDEX=7
LAST_NAME_COLUMN_INDEX=5
PASSWORD_COLUMN_INDEX=3

def login(_browser); end
if File.file?(File.expand_path LOGIN_HELPER_FILE)
  require LOGIN_HELPER_FILE
end

require_relative 'helpers.rb'

$change_email_allowed = false
$dry_run = true
$only_one = true

def setup_browser
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("user-data-dir=./profile")
  @browser = Selenium::WebDriver.for :chrome, options: options
  @browser.navigate.to "https://thekey.me/cas-management/users/admin"

  login(@browser)

  wait = Selenium::WebDriver::Wait.new(timeout: 200) # seconds
  wait.until { @browser.find_element(css: 'input#email') }
end

def connect_to_drive_file
  # how?
  session = GoogleDrive::Session.from_config("config.json")
  ws = session.spreadsheet_by_key(SPREADSHEET_KEY).worksheets[SHEET_INDEX]
  @headers = ws.rows.first.map(&:strip)
  @file = ws
end

def loop_over_rows
  rows = @file.rows[(START_ROW_NUMBER - 1)..(END_ROW_NUMBER - 1)]
  rows.each_with_index do |r, index|
    run_cleanup(r, index)

    break if $only_one
  end
end

def run_cleanup(r, index)
  go_to_profile(r)
  set_password(r)

  go_to_profile(r)
  reset_mfa

  go_to_profile(r)
  change_group

  add_alias(r) # currently does nothing

  go_to_profile(r)
  update_name_and_email(r)

  save_note(index + START_ROW_NUMBER, 'success')
rescue => error
  save_note(index + START_ROW_NUMBER, error.message)
end

# done
def go_to_profile(r, email = nil)
  email ||= r[EXISTING_EMAIL_COLUMN_INDEX]

  raise "no email provided" if email == ''

  @browser.navigate.to "https://thekey.me/cas-management/users/admin"
  element = @browser.find_element(css: 'input#email')
  element.send_keys email
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
  first_name = row[FIRST_NAME_COLUMN_INDEX]
  preferred_name = row[PREFERRED_NAME_COLUMN_INDEX]
  last_name = row[LAST_NAME_COLUMN_INDEX]

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
    @browser.find_element(id: 'email').send_keys(row[DESIRED_EMAIL_COLUMN_INDEX])
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
  @browser.find_element(id: 'password').send_keys(row[PASSWORD_COLUMN_INDEX])

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
  return unless G_GROUP_NAME

  @browser.find_element(css: '[data-target="#googleGroupsCollapsible"]').click

  sleep 0.5
  xpath_selector = "//*[text() = '#{G_GROUP_NAME}']"
  group_select = @browser.find_elements(xpath: xpath_selector).first
  raise 'google group not found' unless group_select
  group_select.click

  return if $dry_run
  @browser.find_element(css: '[name="_eventId_updateGoogleGroup"]').click
  # wait a half second for page to save
  sleep 0.5
end

def add_alias(row)

end

def save_note(row_number, text)
  @file[row_number, 14] = text
  @file.save
end

def run
  connect_to_drive_file
  setup_browser
  loop_over_rows
end

begin
  run
  p 'success! 🎉'
  sleep 1
rescue StandardError => error
  p error
  sleep 20
  @browser&.quit
end
