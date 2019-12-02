require 'RMagick'
require 'sinatra'
require 'httparty'

def sign_in
  response = HTTParty.post('http://localhost:5000/api/user/signin', body: {"email": "testing1234567@gmail.com", "password": "123456"})
  return response.headers["set-cookie"]
end

def request_plot_points(cookie, project_id, parameter)
  response = HTTParty.post("http://localhost:5000/api/project/populate-floorplan-image/#{project_id}", headers: {"Content-Type": "application/json", "Cookie": cookie }, body: {"parameter": parameter, "type": "scanner"}.to_json)
  return JSON.parse(response.body)
end

def generate_images(project_id, datapoints, parameter)
  files = []
  datapoints.each_key do |floor|
    next if floor == '7'
    image = Magick::Image.read("sackings/floor#{floor}.jpg").first
    height, width = image.rows, image.columns
    gc = Magick::Draw.new
    # puts "Height: #{height}px, Width: #{width}px"

    parameter == 'RSRP' ? (gc.stroke, gc.fill = "red", "red") : (gc.stroke, gc.fill = "blue", "blue")

    datapoints[floor].each_key do |channel|
      datapoints[floor][channel].each do |reading|
        y_cord = -reading["latitude"].to_f + height
        x_cord = reading["longitude"].to_f

        gc.point(x_cord, y_cord - 1)
        gc.point(x_cord + 1, y_cord - 1) 
        gc.point(x_cord, y_cord)
        gc.point(x_cord + 1, y_cord)
        gc.point(x_cord, y_cord + 1)
        gc.point(x_cord + 1, y_cord + 1)
      end
      gc.draw(image)
      filename = "#{project_id}_#{channel}_floor#{floor}_#{parameter}.jpg"
      image.write('results/' + filename)
      files << filename if image.write(filename)
    end
  end
  return files
end

def generate_images_by_floor(project_id, datapoints, parameter, images)
  files = []
  datapoints.each_key do |floor|
    next if floor == '7'
    image = Magick::Image.read("sackings/floor#{floor}.jpg").first
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

        gc.point(x_cord, y_cord - 1)
        gc.point(x_cord + 1, y_cord - 1) 
        gc.point(x_cord, y_cord)
        gc.point(x_cord + 1, y_cord)
        gc.point(x_cord, y_cord + 1)
        gc.point(x_cord + 1, y_cord + 1)
      end
      gc.draw(image)
      filename = "#{project_id}_#{channel}_floor#{floor}_#{parameter}.jpg"
      image.write('results/' + filename)
      if image.write('results/' + filename)
        images[channel]["byFloor"]["floor#{floor}"][parameter] = filename
        files << filename 
      end
    end
  end
  return images
end

post '/render/:id' do
  # cookie = sign_in
  body = JSON.parse(request.body.read)
  rsrp = body['RSRP']
  rsrq = body['RSRQ']
  cinr = body['CINR']
  pci = body['PCI']
  files = []
  images = {}

  generate_images_by_floor(params[:id], rsrp, 'RSRP', images)
  generate_images_by_floor(params[:id], rsrq, 'RSRQ', images)
  generate_images_by_floor(params[:id], cinr, 'CINR', images)
  pci.each { |obj| generate_images_by_floor(params[:id], obj, 'PCI', images) }
  images = images.to_json
  return images
end