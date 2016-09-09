
/**
 *  Default upload config
 *
 */

module.exports = {
  uploadStates: [
    'enqueued',
    'pending',
    'importing',
    'uploading',
    'guessing',
    'unpacking',
    'getting',
    'creating',
    'complete'
  ],
  fileExtensions: [
    'csv',
    'xls',
    'xlsx',
    'zip',
    'dji',
    'kml',
    'geojson',
    'json',
    'ods',
    'kmz',
    'tsv',
    'gpx',
    'tar',
    'gz',
    'tgz',
    'osm',
    'bz2',
    'tif',
    'tiff',
    'txt',
    'sql',
    'rar',
    'carto',
    'gpkg'
  ],
  // How big should file be?
  fileTimesBigger: 3
}
