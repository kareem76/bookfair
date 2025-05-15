require 'mechanize'
require 'csv'
require 'json'
require 'uri'

# Initialize Mechanize
agent = Mechanize.new
agent.user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

# Read input file from ARGV
input_file = ARGV[0] || 'list.txt'
urls = File.readlines(input_file).map(&:strip)

# Array to hold book data for JSON export
books_data = []

begin
  CSV.open("books_data.csv", "wb") do |csv|
    # Write the header row
    csv << ["Title", "Author", "Year", "Publisher", "ISBN", "URL", "Category | Subcategory", "Image URL", "Price", "Summary"]

    urls.each do |original_url|
      puts "Processing URL: #{original_url}"
      visited_urls = []
      url = original_url

      loop do
        break if visited_urls.include?(url)
        visited_urls << url

        begin
          page = agent.get(url)
        rescue => e
          puts "❌ Failed to load page: #{url} – #{e.message}"
          break
        end

        puts "Page title: #{page.title}"

        book_links = page.search('a.product_name.one_line')
        book_links.each do |link|
          book_url = link['href']
          book_title = link.text.strip
          puts "📚 Scraping: #{book_title} – #{book_url}"

          begin
            details_page = agent.get(book_url)
            subcategory = book_url.split('/')[3].gsub('-', ' ')
            category = details_page.css('li[itemprop="itemListElement"]').at(1).css('span[itemprop="name"]').text rescue 'N/A'
            author = details_page.at('.product-manufacturer a')&.text&.strip || 'N/A'
            isbn = details_page.at('.product-reference span[itemprop="sku"]')&.text&.strip || 'N/A'
            year = details_page.at('dt.name:contains("سنة النشر") + dd.value')&.text&.strip || 'N/A'
            publisher = details_page.at('dt.name:contains("دار النشر") + dd.value')&.text&.strip || 'N/A'
            image_url = details_page.at('div.easyzoom a')&.[]('href') || 'N/A'
            price = details_page.at('.price')&.text&.strip || 'N/A'
            summary = details_page.at('.product-description')&.text&.strip || 'N/A'

            csv << [book_title, author, year, publisher, isbn, book_url, "#{category} | #{subcategory}", image_url, price, summary]

            books_data << {
              title: book_title,
              author: author,
              year: year,
              publisher: publisher,
              isbn: isbn,
              url: book_url,
              category: "#{category} | #{subcategory}",
              image_url: image_url,
              price: price,
              summary: summary
            }

          rescue => e
            puts "⚠️ Failed to scrape book at #{book_url}: #{e.message}"
            next
          end
        end

        next_link = page.at('a[rel="next"]')
        break unless next_link
        url = URI.join(page.uri, next_link['href']).to_s
        puts "➡️ Next page: #{url}"
      end
    end
  end

  # Write all data to JSON once at the end
  File.open("books_data.json", "w") do |f|
    f.write(JSON.pretty_generate(books_data))
  end

rescue => e
  puts "❌ General error: #{e.message}"
end

puts "✅ Scraping completed."
