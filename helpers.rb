def find_button(driver, text)
  driver.find_element(css: "input[value='#{text}']")
end

def wait_for(search)
  @browser.find_element(search)
end

def char_to_col_index(char)
  return char if char.is_a? Numeric
  char.upcase.ord - 65
end