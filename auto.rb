require 'selenium-webdriver'
require 'google_drive'
require 'pry-byebug'
require 'yaml'

LOGIN_HELPER_FILE = '~/key_login.rb'
def login(_browser); end
if File.file?(File.expand_path LOGIN_HELPER_FILE)
  require LOGIN_HELPER_FILE
end

require_relative 'helpers.rb'

CONFIG = YAML.load_file("config.yml")
puts CONFIG
raise 'No config given' if CONFIG == false || CONFIG.keys.none?

CAS_MANAGE_SEARCH_PAGE = 'https://thekey.me/cas-management/users/admin'
SPREADSHEET_KEY = CONFIG['spreadsheet']['key']
SHEET_INDEX = CONFIG['spreadsheet']['index']
G_GROUP_NAME = CONFIG['g_group_name']

# use the actual row numbers (the first row is 1, not 0)
START_ROW_NUMBER = ENV['START_ROW_NUMBER']&.to_i || CONFIG['start_row_number']
END_ROW_NUMBER = ENV['END_ROW_NUMBER']&.to_i || CONFIG['end_row_number']
# example to run this on specific rows:
# START_ROW_NUMBER=260 END_ROW_NUMBER=387 PROFILE_NUMBER=2 ruby auto.rb

EXISTING_EMAIL_COLUMN_INDEX= char_to_col_index CONFIG['existing_email_column_index']
DESIRED_EMAIL_COLUMN_INDEX= char_to_col_index CONFIG['desired_email_column_index']
FIRST_NAME_COLUMN_INDEX= char_to_col_index CONFIG['first_name_column_index']
PREFERRED_NAME_COLUMN_INDEX= char_to_col_index CONFIG['preferred_name_column_index']
LAST_NAME_COLUMN_INDEX= char_to_col_index CONFIG['last_name_column_index']
PASSWORD_COLUMN_INDEX= char_to_col_index CONFIG['password_column_index']
NOTE_COLUMN_INDEX= char_to_col_index CONFIG['note_column_index']
ALIAS_COLUMN_INDEX= char_to_col_index CONFIG['alias_column_index']

$change_email_allowed = false
$dry_run = true
$only_one = true

def setup_browser
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument(user_data_dir)
  @browser = Selenium::WebDriver.for :chrome, options: options
  @browser.navigate.to "https://thekey.me/cas-management/users/admin"

  login(@browser)

  wait = Selenium::WebDriver::Wait.new(timeout: 200) # seconds
  wait.until { @browser.find_element(css: 'input#email') }
end

def user_data_dir
  return "user-data-dir=./profile" unless ENV['PROFILE_NUMBER']
  "user-data-dir=./profile-#{ENV['PROFILE_NUMBER']}"
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

# order from Scott on 2020-02-06
# 1. Search on "K" change email to "C" (save)
# 2 Search on "C" then change names (save)
# 3 Search on "C" then Reset MFA
# 4 change password (save)
# 5 Search on "C" then change then change Google Organization, (wait)
# 6 Search on "C" then change aliases
def run_cleanup(r, index)
  found = safe_go_to_profile(r, nil, true)
  update_email(r) if found
  new_email = nil
  new_email = r[DESIRED_EMAIL_COLUMN_INDEX] if $change_email_allowed

  go_to_profile(r, new_email)
  update_name(r)

  go_to_profile(r, new_email)
  reset_mfa

  set_password(r)

  go_to_profile(r, new_email)
  change_group(r)

  if ALIAS_COLUMN_INDEX
    go_to_profile(r, new_email)
    add_aliases(r) # currently does nothing
  end

  save_note(index + START_ROW_NUMBER, 'success')
rescue => error
  save_note(index + START_ROW_NUMBER, error.message)
end

def safe_go_to_profile(r, email = nil, reload = false)
  go_to_profile(r, email, reload)
rescue => error
  raise error unless error.message == "person not found"
  nil
end

# done
def go_to_profile(r, email = nil, reload = false)
  email ||= r[EXISTING_EMAIL_COLUMN_INDEX]

  raise "no email provided" if email == ''

  go_to_search_page(reload)

  element = @browser.find_element(css: 'input#email')
  element.clear
  element.send_keys email
  find_button(@browser, 'Search').click

  check_for_multiple_results

  find_button(@browser, 'Edit').click
  true
end

def go_to_search_page(reload)
  h1 = @browser.find_element(css: 'h1')
  return if !reload && h1.text == 'User Search' && h1.displayed?

  @browser.navigate.to CAS_MANAGE_SEARCH_PAGE
  @browser.find_element(css: '.card.mb-3 input#email')
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
def update_name(row)
  first_name = row[FIRST_NAME_COLUMN_INDEX]
  preferred_name = PREFERRED_NAME_COLUMN_INDEX ? row[PREFERRED_NAME_COLUMN_INDEX] : ''
  last_name = row[LAST_NAME_COLUMN_INDEX]

  @browser.find_element(id: 'firstName').clear
  @browser.find_element(id: 'firstName').send_keys(first_name)

  if preferred_name != ''
    @browser.find_element(id: 'preferredName').clear
    @browser.find_element(id: 'preferredName').send_keys(preferred_name)
  end

  @browser.find_element(id: 'lastName').clear
  @browser.find_element(id: 'lastName').send_keys(last_name)

  return if $dry_run
  @browser.find_element(css: '[name="_eventId_save"]').click
  # wait for page to save
  sleep 0.1
  wait_for(css: '.card-header')
end

# done
def update_email(row)
  return unless $change_email_allowed

  @browser.find_element(id: 'email').clear
  @browser.find_element(id: 'email').send_keys(row[DESIRED_EMAIL_COLUMN_INDEX])

  return if $dry_run

  @browser.find_element(css: '[name="_eventId_save"]').click
  # wait for page to save
  sleep 1
  wait_for(css: '.card-header')
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

def change_group(row)
  return if [nil, ''].include? group_name(row)

  sleep 1
  @browser.find_element(css: '[data-target="#googleGroupsCollapsible"]').click
  sleep 1

  xpath_selector = "//*[text() = '#{group_name(row)}']"
  group_select = @browser.find_elements(xpath: xpath_selector).first
  raise 'google group not found' unless group_select
  group_select.click

  sleep 0.5

  return if $dry_run
  @browser.find_element(css: '[name="_eventId_updateGoogleGroup"]').click
  # wait a half second for page to save
  sleep 0.5
end

def group_name(row)
  return if [nil, ''].include? G_GROUP_NAME
  return G_GROUP_NAME if G_GROUP_NAME.is_a? String

  group_name = row[G_GROUP_NAME]
  return if [nil, ''].include? group_name
  group_name
end

def add_aliases(row)
  aliases = row[ALIAS_COLUMN_INDEX].to_s.downcase
  return unless aliases.strip.length > 0

  @browser.find_element(css: '.select2-selection').click
  @browser.find_element(css: '.select2-search--inline input').send_keys(aliases)
  sleep(0.1)

  return if $dry_run
  @browser.find_element(css: '[name="_eventId_save"]').click
  # wait for page to save
  sleep 0.1
  wait_for(css: '.card-header')
end

def save_note(row_number, text)
  @file[row_number, NOTE_COLUMN_INDEX + 1] = text
  @file.save
end

def run
  connect_to_drive_file
  setup_browser
  loop_over_rows
end

begin
  run
  p 'done! 🎉'
  sleep 1
rescue StandardError => error
  p error
  sleep 20
  @browser&.quit
end
