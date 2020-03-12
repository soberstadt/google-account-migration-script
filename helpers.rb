def find_button(driver, text)
  driver.find_element(css: "input[value='#{text}']")
end

def wait_for(search)
  @browser.find_element(search)
end
