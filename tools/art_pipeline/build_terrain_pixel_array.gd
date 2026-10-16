extends SceneTree

## Compile the small albedo PNGs into one reusable array for all map tiles.
func _initialize() -> void:
	var report := build()
	print(JSON.stringify(report)); quit(0 if report.status=="PASS" else 1)

static func build() -> Dictionary:
	if DisplayServer.get_name() == "headless":
		push_error("Build the texture array with the native GPU renderer, using run_terrain_pixel_review.py")
		return {"status":"FAIL"}
	var images: Array[Image] = []
	var rows: Array = []
	for stem: String in TerrainTextureCatalog.SURFACES:
		var path: String = TerrainTextureCatalog.DIR + stem + "_albedo.png"
		var image := Image.load_from_file(ProjectSettings.globalize_path(path))
		if image == null or image.get_size() != Vector2i(128,128):
			push_error("Invalid terrain surface: " + path); return {"status":"FAIL"}
		image.convert(Image.FORMAT_RGB8)
		image.generate_mipmaps()
		images.append(image)
		rows.append({"stem":stem,"width":128,"height":128,"mipmaps":image.get_mipmap_count()})
	var array := Texture2DArray.new()
	var error := array.create_from_images(images)
	if error != OK:
		push_error("Cannot create pixel terrain array: " + str(error)); return {"status":"FAIL"}
	for layer in range(images.size()):
		var stored := array.get_layer_data(layer)
		if stored != null: stored.convert(Image.FORMAT_RGB8)
		if stored == null or stored.get_data() != images[layer].get_data():
			push_error("Array layer differs from source: " + str(layer)); return {"status":"FAIL"}
	error = ResourceSaver.save(array, TerrainTextureCatalog.ARRAY_PATH, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Cannot save pixel terrain array: " + str(error)); return {"status":"FAIL"}
	var water: String = TerrainTextureCatalog.DIR + "water_albedo.png.import"
	var config := ConfigFile.new()
	if config.load(water)==OK:
		config.set_value("params","compress/mode",0)
		config.set_value("params","mipmaps/generate",true)
		config.set_value("params","detect_3d/compress_to",0)
		config.save(water)
	var report := {"status":"PASS","layers":images.size(),"resolution":[128,128],"mipmaps":true,"source_pixels_preserved":true,"array_path":TerrainTextureCatalog.ARRAY_PATH,"assets":rows}
	var file := FileAccess.open("res://docs/terrain_pixel_array_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	return report
