require "selenium-webdriver"

def find_button(driver, text)
  driver.find_element(css: "input[value='#{text}']")
end

driver = Selenium::WebDriver.for :chrome
driver.navigate.to "https://thekey.me/cas-management/users/admin"


wait = Selenium::WebDriver::Wait.new(timeout: 200) # seconds
wait.until { driver.find_element(css: 'input#email') }

element = driver.find_element(css: 'input#email')
element.send_keys "soberstadt@gmail.com"

sleep 1

find_button(driver, 'Search').click
find_button(driver, 'Edit').click

puts driver.title

sleep 3

driver.quit