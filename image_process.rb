require 'RMagick'
require 'sinatra'
require 'httparty'
require 'dotenv/load'

def sign_in
  response = HTTParty.post('http://localhost:5000/api/user/signin', body: {"email": "testing1234567@gmail.com", "password": "123456"})
  return response.headers["set-cookie"]
end

def request_plot_points(cookie, project_id, parameter)
  response = HTTParty.post("http://localhost:5000/api/project/populate-floorplan-image/#{project_id}", headers: {"Content-Type": "application/json", "Cookie": cookie }, body: {"parameter": parameter, "type": "scanner"}.to_json)
  return JSON.parse(response.body)
end

def generate_images_by_floor(project_id, datapoints, parameter, images)
  files = []
  datapoints.each_key do |floor|
    next if floor == '7'
    image = Magick::Image.read("#{ENV['IMAGE_FOLDER']}/floor#{floor}.jpg").first
    height, width = image.rows, image.columns
    gc = Magick::Draw.new
    # puts "Height: #{height}px, Width: #{width}px"

    parameter == 'RSRP' ? (gc.stroke, gc.fill = "red", "red") : (gc.stroke, gc.fill = "blue", "blue")

    datapoints[floor].each_key do |channel|
      images[channel] = {} if !images.has_key?(channel)
      images[channel]["byFloor"] = {} if !images[channel].has_key?("byFloor")
      if !images[channel]["byFloor"].has_key?("floor#{floor}")
        images[channel]["byFloor"]["floor#{floor}"] = {} 
      end
      if !images[channel].has_key?("parameters")
        images[channel]["parameters"] = []
      end
      if !images[channel]["parameters"].include?(parameter)
        images[channel]["parameters"] << parameter 
      end
      datapoints[floor][channel].each do |reading|
        y_cord = -reading["latitude"].to_f + height
        x_cord = reading["longitude"].to_f
        if reading.has_key?('color')
          color = reading['color']
          gc.stroke = "##{color}"
          gc.fill = "##{color}"
          # gc.stroke_width = 15
        end

        # gc.point(x_cord, y_cord)

        # SINCE STROKE WIDTH DOES NOT WORK NEED TO PLOT SURROUNDING POINTS
        [-3, -2, -1, 0, 1, 2, 3].each do |x|
          plot_x = x_cord + x
          [-3, -2, -1, 0, 1, 2, 3].each do |y|
            plot_y = y_cord + y
            gc.point(plot_x, plot_y)
          end
        end
      end
      gc.draw(image)
      filename = "#{project_id}_#{channel}_floor#{floor}_#{parameter}.jpg"
      if image.write("#{ENV['IMAGE_RESULTS']}/#{filename}")
        puts "saved" + filename
        images[channel]["byFloor"]["floor#{floor}"][parameter] = filename
        files << filename 
      end
    end
  end
  return images
end

post '/render/:id' do
  body = request.body.read
  body = JSON.parse(body)
  rsrp = body['RSRP']
  rsrq = body['RSRQ']
  cinr = body['CINR']
  pci = body['PCI']
  legend = body['legend']
  files = []
  images = {}

  generate_images_by_floor(params[:id], rsrp, 'RSRP', images)
  generate_images_by_floor(params[:id], rsrq, 'RSRQ', images)
  generate_images_by_floor(params[:id], cinr, 'CINR', images)
  pci.each { |obj| generate_images_by_floor(params[:id], obj, 'PCI', images) }
  images = images.to_json
  return images
end