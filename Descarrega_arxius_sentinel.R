# Install necessary packages if not already installed

library(httr)
library(jsonlite)
library(dplyr)
library(xml2)
library(raster)
library(terra)
library(sf)
library(sp)

########    Filtrar i enviar la consulta per obtindre llistat de productes del cataleg ##########

#Definim la URL base de la consulta del cataleg
url_dataspace <- "https://catalogue.dataspace.copernicus.eu/odata/v1"

# Definim els parametres del filtre

satellite <- "SENTINEL-2" # Seleccionem el satelit

level <- "S2MSI2A" # Seleccionem el sentinel -2 amb dades tractades

cloud_cover_max <- 10 # Cobertura de nuvols

# Podem definir l area dinteres  (AOI)  o un punt en l area d interes

# En el cas d un punt unicament posarem longitut-espai-latitut

aoi_point <- "POINT(2.741089 41.630515)"

# Per el poligon latitud_espai_longitut,coma, espai, latitud.... cal repetir al final el primer punt per tancar el poligon!!!

aoi_polygon <-"POLYGON ((2.18914 41.378988, 2.18914 41.406401, 2.223129 41.406401, 2.223129 41.378988, 2.18914 41.378988))"

#definim les dates de la consulta

start_date <- "2024-08-08"

end_date <- "2024-08-10"

# Cal definir també les hores en aquet format

start_date_full <- paste0(start_date, "T00:00:00.000Z")

end_date_full <- paste0(end_date, "T00:00:00.000Z")

#Juntem en un link tots els parametres de filtratge

query <- paste0(url_dataspace, "/Products?$filter=Collection/Name%20eq%20'", satellite, "'%20and%20Attributes/OData.CSC.StringAttribute/any(att:att/Name%20eq%20'productType'%20and%20att/OData.CSC.StringAttribute/Value%20eq%20'", level, "')%20and%20OData.CSC.Intersects(area=geography'SRID=4326;", URLencode(aoi_polygon), "')%20and%20ContentDate/Start%20gt%20", start_date_full, "%20and%20ContentDate/Start%20lt%20", end_date_full)

#Pasem la consulta a traves de l API amb GET i obtenim resposta

response <- GET(query)

# Extraccio i procesament del JSON de la resposta

response_content <- content(response, "text", encoding = "UTF-8")

response_json <- fromJSON(response_content)

#El json el pasem a dataframe

result <- as.data.frame(response_json$value)

# Filtrem els productes nomes disponibles online , es a dir columna 'Online' es TRUE

result <- filter(result, Online == TRUE)

# Podem mostrar nomes els deu primer resultats

head(result, 10)

#Podem visualtitzar el dataframe

view(result)

###############################################################################

#Per descarregar les imatges cal autentificar-se, per tant primer creare token d
#d acces

#########    Crear token d acces     ########

# PEr autentificarse cal tindre un conte amb usuari i contrasenya ja creats amb antelacio

username = "ramonservitje@gmail.com"
password = "P4t4t4252525#"

# L URL d autentificacio del serveis

auth_server_url <- "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token"

# Preparem les dades necesaries en una llista per l autenttificacio

data <- list(
  "client_id" = "cdse-public",
  "grant_type" = "password",
  "username" = username,
  "password" = password
)

# Enviem la consulta al servidor i obtenim resposta

response <- POST(auth_server_url, body = data, encode = "form", verify = TRUE)

#Modifiquem la resposta per convertir-la en el token d autentificacio

access_token <- fromJSON(content(response, "text", encoding = "UTF-8"))$access_token


########## Download the metadata file (.xml)   ################

# Set the Authorization header using obtained access token

headers <- add_headers(Authorization = paste("Bearer", access_token))

# Extract product information for the third product in the list

product_row_id <- 1 # The third images in the list (Nov 5th, 2023)

product_id <- result[product_row_id, "Id"]
product_name <- result[product_row_id, "Name"]

# Create the URL for MTD file
url_MTD <- paste0(url_dataspace, "/Products(", product_id, ")/Nodes(", product_name, ")/Nodes(MTD_MSIL2A.xml)/$value")

# GET request for MTD file and handle redirects
response <- httr::GET(url_MTD, headers, config = httr::config(followlocation = FALSE))
print(response$status_code)

# Extract the final URL for MTD file
url_MTD_location <- response$headers[["Location"]]
print(url_MTD_location)

# Download the MTD file
file <- httr::GET(url_MTD_location, headers, config = httr::config(ssl_verifypeer = FALSE, followlocation = TRUE))

# Set working directory and save the MTD file
setwd("C:/Sentinel")
outfile <- file.path(getwd(), "MTD_MSIL2A.xml")
writeBin(content(file, "raw"), outfile)

######   Read the Metadata File and Extract URL Path  #########

# Load XML2 library for XML processing
library(xml2)

# Read the MTD XML file
tree <- read_xml(outfile)
root <- xml_root(tree)

# Get paths for individual bands in Sentinel-2 granule
band_path <- list()
for (i in 1:4) {
  band_path[[i]] <- strsplit(paste0(product_name, "/", xml_text(xml_find_all(root, ".//IMAGE_FILE"))[i], ".jp2"), "/")[[1]]
}

# Display band paths
for (band_node in band_path) {
  cat(band_node[2], band_node[3], band_node[4], band_node[5], band_node[6], "\n")
}



# Build URLs for individual bands and download them DEscarrega de les imatges
for (band_node in band_path) {
  url_full <- paste0(url_dataspace, "/Products(", product_id, ")/Nodes(", product_name, ")/Nodes(", band_node[2], ")/Nodes(", band_node[3], ")/Nodes(", band_node[4], ")/Nodes(", band_node[5], ")/Nodes(", band_node[6], ")/$value")
  print(url_full)

  # Perform GET request and handle redirects
  response <- GET(url_full, headers, config = httr::config(followlocation = FALSE))

  if (status_code(response) %in% c(301, 302, 303, 307)) {
    url_full_location <- response$headers$location
    print(url_full_location)
  }

  # Download the file
  file <- httr::GET(url_full_location, headers, config = httr::config(ssl_verifypeer = FALSE, followlocation = TRUE))
  print(status_code(file))

  # Save the product
  outfile <- file.path(getwd(), band_node[6])
  writeBin(content(file, "raw"), outfile)
  cat("Saved:", band_node[6], "\n")
}


######## Llegint els arxius “jp2” descarregats, tractant-los i visualitzant-los  ########

# Set the folder path
folder_path <- getwd()

# List all files with the ".jp2" extension
jp2_files <- list.files(path = folder_path, pattern = "\\.jp2$", ignore.case = TRUE, full.names = TRUE)

# Print the list of files
print(jp2_files)

# Extract Blue, Green, and Red bands based on their file names
blue_band  <- jp2_files[grep("_B02_", jp2_files)]
green_band <- jp2_files[grep("_B03_", jp2_files)]
red_band   <- jp2_files[grep("_B04_", jp2_files)]

# Creem una llista amb els rasters que ens interesen.

file_list <- c(blue_band, green_band, red_band)

# Define the AOI polygon
# del exemple   aoi_polygon <- "POLYGON ((-121.0616 37.6391, -120.966 37.6391, -120.966 37.6987, -121.0616 37.6987, -121.0616 37.6391))"
#........aol_polygon <-  "POLYGON ((2.189144 41.406401,2.223129 41.406401,2.223129 41.378988,2.18914 41.378988))"
# Read and convert the AOI polygon to an sf object
aoi <- st_as_sfc(aoi_polygon)
#aoi <- st_read(aoi)

# Define the initial CRS for the AOI polygon (assuming it's in WGS84, EPSG:4326)
aoi <- st_set_crs(aoi, 4326)

# Read the first raster file to get its projection
raster_file <- raster(file.path(file_list[1]))
raster_projection <- projection(raster_file)

# Reproject the AOI polygon to match the raster projection
aoi_transformed <- st_transform(aoi, raster_projection)

# Read, clip, and stack the raster files
raster_list <- lapply(file_list, function(file) {
  raster_file <- raster(file)
  raster_clipped <- crop(raster_file, st_bbox(aoi_transformed))
  return(raster_clipped)
})

raster_stack <- stack(raster_list)

####  Plot rasters  #######

# Plot the stacked raster
plot(raster_stack)

# Extract individual bands from the stacked raster
blue <- raster_stack[[1]]
green <- raster_stack[[2]]
red <- raster_stack[[3]]

# Set gain for better visualization
gain <- 3

# Normalize the bands and apply gain
blue_n <- clamp(blue * gain / 10000, 0, 1)
green_n <- clamp(green * gain / 10000, 0, 1)
red_n <- clamp(red * gain / 10000, 0, 1)

# Create an RGB composite
rgb_composite_n <- brick(red_n, green_n, blue_n)

# Plot the RGB composite
plotRGB(rgb_composite_n, scale = 1, stretch = "lin")

