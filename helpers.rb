def find_button(driver, text)
  driver.find_element(css: "input[value='#{text}']")
end