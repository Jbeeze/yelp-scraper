require 'open-uri'
require 'csv'
require 'fileutils'
require 'mechanize'

@base_url = "http://www.yelp.com/search?find_desc&l=g:"
@user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_0) AppleWebKit/535.2 (KHTML, like Gecko) Chrome/15.0.854.0 Safari/535.2"
@links_collected = 0
@LOCAL_DIR = 'yelp-search-pages-coventry'
@max_count = 0
@coordinatesArray = [-71.50760248303413,41.72452151711228,-71.6154058277607,41.66042955869992] 
@aliases = ['Windows IE6','Windows IE 7', 'Windows Mozilla', 'Mac Safari','Mac Firefox','Mac Mozilla']

FileUtils.makedirs(@LOCAL_DIR) unless File.exists?@LOCAL_DIR

def setUserAgent()
	@a = Mechanize.new do |agent|
		agent.user_agent_alias = @aliases.sample
	end	
end

def setNewMechanizeAgent()
	@a = Mechanize.new {|agent| 
		agent.user_agent_alias = 'Mac Safari'
	}
end



def coordsQuery()
	setNewMechanizeAgent()	
	
	if @coordinatesArray.length != 0
		x1, y1, x2, y2 = @coordinatesArray[0],@coordinatesArray[1],@coordinatesArray[2],@coordinatesArray[3]

		numberofSquares = ((@coordinatesArray.length)/4)
		puts "#{numberofSquares} squares to scrape."

		remove()

		url = @base_url + x1.to_s + ',' + y1.to_s + ',' + x2.to_s + ',' + y2.to_s + '&start=0'
		content = a.get(url)
		puts url

		sleep 2 + rand
	
		if content.at('span.pagination-results-window')
			amountOfSearchResults = content.at('span.pagination-results-window').text.strip
			results = amountOfSearchResults[15..25].strip.to_i 
		else
			puts "No results in this square. Moving to next square..."
			coordsQuery()
		end
	
		puts "Found #{results} results in the square"

		if(results.to_i > 1000) #create 4 new squares and check those results
			puts "Splitting one square into four"
			puts "\n"
			splitSquare(x1,y1,x2,y2)
		end

		scrape([x1,y1,x2,y2])

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
	return ((a.to_f+b.to_f)/2)
end

def scrape(coordinates) #scrapes the links off the search results page and sends to pageScraper
	setNewMechanizeAgent()		

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
	coords_url = base_url + x1 + ',' + y1 + ',' + x2 + ',' + y2 + '&start='

	content = a.get(coords_url)

	pages = content.at('div.page-of-pages').text.gsub(/\s+/, " ")[10..15].strip.to_i

	puts "Scraping #{coords_url}"
	puts "#{pages} Pages to scrape. Scraping now..."

	lastResultPage = (pages * 10) - 10
	pageCount = 1
	
	while count <= lastResultPage
		url = coords_url + '&start=' + count.to_s 
		

		content = a.get(url)
		@max_count += 1
		File.open("#{@LOCAL_DIR}/Page#{@max_count}.html", 'w'){|f| f.write(content.body)}
		count += 10
		puts "Page #{pageCount} of #{pages}"
		pageCount += 1

		content.search('div.biz-listing-large').each do |listing|
			name = listing.at('a.biz-name')
			names.push(name.text)
			href = name['href']
			
			if href.include? '/biz'
				links.push(href)
			end

			if listing.at('address')
				addresses.push(listing.at('address').text.strip)
			else
				addresses.push("No Address Listed on Results Page")
			end

			if listing.at('span.biz-phone')
				phoneNumbers.push(listing.at('span.biz-phone').text.strip)
			else
				phoneNumbers.push("No Phone Number Listed")
			end

			if listing.at('span.category-str-list')
				categories.push(listing.at('span.category-str-list').text.strip)
			else
				categories.push('No Categories Listed')
			end
		end
		sleep 2 + rand
	end

	puts "\n"

	@links_collected += links.length

	CSV.open('coventry.csv','a+') do |csv|
		(0..names.length).each do |index|
			csv << [names[index], addresses[index], phoneNumbers[index], categories[index], links[index]]
		end
	end
	sleep 2 + rand
	coordsQuery()
end
#setUserAgent()
coordsQuery()