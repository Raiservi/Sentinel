######## Llegint els arxius “jp2” descarregats, tractant-los i visualitzant-los  ########

#Tot ho farem amb terra


library(terra)
library(sf)
library(ggplot2)
library(sp)
library(raster)



# Establim el directori de treball al  del projecte
folder_path <- getwd()

# llistem tots els arxius amb l extensio  ".jp2" del directori de treball

jp2_files <- list.files(path = folder_path, pattern = "\\.jp2$", ignore.case = TRUE, full.names = TRUE)

print(jp2_files)


# anomenem els rasters en funcio del seu nom  arxiu ( es l estandard de sentinel 2;
#B02 blau, B03 verd, B04 vermell i B08 NIR )

blue_band  <- jp2_files[grep("_B02_", jp2_files)]
green_band <- jp2_files[grep("_B03_", jp2_files)]
red_band   <- jp2_files[grep("_B04_", jp2_files)]
nir_band  <-  jp2_files[grep("_B08_", jp2_files)]

# Creem una llista amb els rasters que ens interesen.

file_list <- c(blue_band, green_band, red_band, nir_band)

# Definim l area geografica   d interes dins de la propia imatge de la descarrega per retallar-la

aol_polygon <-  "POLYGON ((2.189144 41.406401,2.223129 41.406401,2.223129 41.378988,2.18914 41.378988, 2.189144 41.406401))"

# Convertim el poligon AOI polygon a un objecte sf

aoi <- st_as_sfc(aol_polygon)

#aoi <- st_read(aoi)

# Definim el  CRS per el poligon  AOI  (assumint que el CRS es  WGS84, EPSG:4326)

aoi <- st_set_crs(aoi, 4326)

# Llegim el primer raster per saber la seva projeccio

raster_file <- raster(file.path(file_list[1]))
raster_projection <- projection(raster_file)

#Reprojectem el poligon d area d interes (aoi) amb la projeccio del raster

aoi_transformed <- st_transform(aoi, raster_projection)

# llegim , retallem segons aoi i construim l estack dels 4 rasters

raster_list <- lapply(file_list, function(file) {
  raster_file <- raster(file)
  raster_clipped <- crop(raster_file, st_bbox(aoi_transformed))
  return(raster_clipped)
})

#Creem el stack de rasters ( en Terra no cal)

raster_stack <- stack(raster_list)

#Creem la mascara de la zona de terra del mapa.
#Amab la banda NIR tot el que sigui >0.5 es na la resta 1



#Apliquem la mascara les 4 capes del raster



# Ara cal contruir amb totes les posicion que es tenen profunditat conegudes




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


##########Creacio de la mascara de les zones de terra#####################


