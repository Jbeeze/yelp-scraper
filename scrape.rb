require 'open-uri'
require 'csv'
require 'fileutils'
require 'nokogiri'

@base_url = "http://www.yelp.com/search?find_desc&l=g:"
@user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2"
@links_collected = 0
#@coordinatesArray = [-75.08434295654297,39.72672123072057,-75.13824462890625,39.6937070724911] #1000ish for PA
#@coordinatesArray = [-122.09190666675568,47.76223920558805,-122.52312004566193,47.530942624932464] #Seattle
#@coordinatesArray = [-80.15616416931152,30.49799935026557,-83.60587120056152,28.10308651532774] #FL mid
@LOCAL_DIR = 'yelp-search-pages'
@coordinatesArray = [-73.84391784667969,40.712989008251256,-73.86966705322266,40.69346859713447]
@max_count = 1

FileUtils.makedirs(@LOCAL_DIR) unless File.exists?@LOCAL_DIR

def coordsQuery() 
	
	if @coordinatesArray.length != 0
		x1, y1, x2, y2 = @coordinatesArray[0],@coordinatesArray[1],@coordinatesArray[2],@coordinatesArray[3]

		numberofSquares = ((@coordinatesArray.length)/4)
		puts "#{numberofSquares} squares to scrape."

		remove()

		url = @base_url + x1.to_s + ',' + y1.to_s + ',' + x2.to_s + ',' + y2.to_s + '&start=0'
		puts url
		content = Nokogiri::HTML(open(url, 'User-Agent' => @user_agent), nil, "UTF-8")
	
		if content.at_css('span.pagination-results-window')
			amountOfSearchResults = content.at_css('span.pagination-results-window').text.strip
			results = amountOfSearchResults[15..25].strip.to_i 
		else
			puts "No results in this square. Moving to next square..."
			remove()
			coordsQuery()
		end
	
		puts "Found #{results} results in the square"

		if(results.to_i > 1000) #create 4 new squares and check those results
			puts "Splitting one square into four"
			puts "\n"
			splitSquare(x1,y1,x2,y2)
		end

		scrape([x1,y1,x2,y2])

		sleep 1 + rand
	else
		puts '*' * 100
		puts "Scrape is complete!"
		puts '*' * 100
		puts "Collected : #{@links_collected} businesses!"
		exit
	end

end

def remove()
	(0...4).each do |coords|
		@coordinatesArray.shift
	end
end

def splitSquare(x1,y1,x2,y2) #takes in an area that has more than 1000 results and splits into 4 squares, then checks again.
	
	x3 = average(x1,x2)
	y3 = average(y1,y2)

	squareA = [x1, y3, x3, y2]
	squareB = [x3, y3, x2, y2]
	squareC = [x3, y1, x2, y3]
	squareD = [x1, y1, x3, y3]

	@coordinatesArray.unshift(squareA[0],squareA[1],squareA[2],squareA[3],squareB[0],squareB[1],squareB[2],squareB[3],squareC[0],squareC[1],squareC[2],squareC[3],squareD[0],squareD[1],squareD[2],squareD[3])
	coordsQuery()

end

def average(a,b) #used to find the mid point of the lat and lon vars
	return ((a+b)/2)
end

def scrape(coordinates) #scrapes the links off the search results page and sends to pageScraper
	x1 = coordinates[0].to_s
	y1 = coordinates[1].to_s
	x2 = coordinates[2].to_s
	y2 = coordinates[3].to_s
	
	names = []
	addresses = []
	phoneNumbers = []
	categories = []
	links = []
	
	count = 0

	base_url = "http://www.yelp.com/search?find_desc&l=g:"
	coords_url = base_url + x1 + ',' + y1 + ',' + x2 + ',' + y2

	content = Nokogiri::HTML(open(coords_url, 'User-Agent' => @user_agent), nil, "UTF-8")

	pages = content.at_css('div.page-of-pages').text.gsub(/\s+/, " ")[10..15].strip.to_i

	puts "#{pages} Pages to scrape. Scraping now..."

	lastResultPage = (pages * 10) - 10
	pageCount = 1
	
	while count <= lastResultPage
		url = coords_url + '&start=' + count.to_s 
		content = Nokogiri::HTML(open(url, 'User-Agent' => @user_agent), nil, "UTF-8")
		@max_count += 1
		File.open("#{@LOCAL_DIR}/NY#{@max_count}.html", 'w'){|f| f.write(content.to_html)}
		count += 10
		puts "Page #{pageCount} of #{pages}"
		pageCount += 1
		

		content.css('div.biz-listing-large').each do |listing|
			name = listing.at_css('a.biz-name')
			names.push(name.text)
			href = name['href']
			links.push(href)

			if listing.at_css('address')
				addresses.push(listing.at_css('address').text.strip)
			else
				addresses.push("No Address Listed on Results Page")
			end

			if listing.at_css('span.biz-phone')
				phoneNumbers.push(listing.at_css('span.biz-phone').text.strip)
			else
				phoneNumbers.push("No Phone Number Listed")
			end

			if listing.at_css('span.category-str-list')
				categories.push(listing.at_css('span.category-str-list').text.strip)
			else
				categories.push('No Categories Listed')
			end
		end
	end

	puts "\n"

	@links_collected += links.length

	CSV.open('NYTest.csv','a+') do |csv|
		(0..names.length).each do |index|
			csv << [names[index], addresses[index], phoneNumbers[index], categories[index], links[index]]
		end
	end
	coordsQuery()
end

coordsQuery()