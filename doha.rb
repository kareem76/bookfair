require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
require 'json'
require 'set'

Capybara.register_driver :chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  Selenium::WebDriver::Chrome.driver_path = nil  # Let Selenium manager handle it

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_driver = :chrome
Capybara.default_max_wait_time = 10

class DohaBookFairScraper
  include Capybara::DSL

  def initialize(group_index = 0, group_size = 31)
    @group_index = group_index.to_i
    @group_size = group_size
  end

  def fetch_publishers
    visit 'https://www.dohabookfair.qa/الزوار/ابحث-عن-كتاب/'
    sleep 2
    find('button#btnAdvance').click
    sleep 2

    publishers = []
    select = find('select#strPublisher', visible: false)
    select.all('option').each do |opt|
      next if opt.text.include?('اختر') || opt[:value].nil? || opt[:value].empty?
      publishers << { name: opt.text.strip, value: opt[:value] }
    end

    publishers.reject { |p| p[:value] == "788" }  # Skip دار الكتب العلمية
  end

  def start
    all_publishers = fetch_publishers
    my_group = all_publishers.each_slice(@group_size).to_a[@group_index] || []

    puts "🟢 Group #{@group_index}: #{my_group.size} publishers"

    my_group.each do |publisher|
      begin
        visit 'https://www.dohabookfair.qa/الزوار/ابحث-عن-كتاب/'
        sleep 2
        find('button#btnAdvance').click
        sleep 2

        execute_script(<<~JS, publisher[:value])
          var select = document.getElementById('strPublisher');
          select.value = arguments[0];
          var event = new Event('change', { bubbles: true });
          select.dispatchEvent(event);
        JS

        sleep 1
        find('button#btnSearch').click
        sleep 3

        begin
          find('select#maxRows').select('500')
          sleep 2
        rescue
          puts "⚠️ Could not set 500 rows for #{publisher[:name]}"
        end

        all_data = []
        seen_titles = Set.new

        loop do
          rows = all('#BookList_Result.table tbody tr')
          break if rows.empty?

          data = rows.map do |tr|
            values = tr.all('td').map { |td| td.text.strip }
            {
              title:     values[1],
              category:  values[2],
              author:    values[3],
              year:      values[4],
              publisher: values[5],
              country:   values[6],
              price:     values[7],
              hall:      values[8]
            }
          end

          new_data = data.reject { |row| seen_titles.include?(row[:title]) }
          break if new_data.empty?

          new_data.each { |row| seen_titles << row[:title] }
          all_data.concat(new_data)

          puts "📘 #{publisher[:name]}: +#{new_data.size} (#{seen_titles.size} total)"

          links = all('a.page-link', minimum: 1)
          next_link = links.last
          break if next_link[:class]&.include?('disabled')
          next_link.click
          sleep 2
        rescue => e
          puts "⚠️ Pagination failed for #{publisher[:name]}: #{e.message}"
          break
        end

        filename = "group_#{@group_index}_publisher_#{publisher[:name].gsub(/[^\p{Arabic}\w\s\-]/, '').gsub(/\s+/, '_')}.json"
        File.write(filename, JSON.pretty_generate(all_data))
        puts "✅ Saved #{all_data.size} books for #{publisher[:name]} to #{filename}"

      rescue => e
        puts "❌ Error scraping publisher #{publisher[:name]}: #{e.message}"
      end
    end
  end
end

group_index = ARGV[0] || "0"
DohaBookFairScraper.new(group_index).start

