// dependencies
var async = require('async');
var AWS = require('aws-sdk');
var gm = require('gm').subClass({ imageMagick: true });
var util = require('util');

// constants
var MAX_WIDTH  = 400;
var MAX_HEIGHT = 400;

// get reference to S3 client 
var s3 = new AWS.S3();
 
exports.handler = function(event, context, callback) {

    // Read options from the event.
    console.log("Reading options from event:\n", util.inspect(event, {depth: 5}));

	// source and destination buckets
    var srcBucket = event.Records[0].s3.bucket.name;

	var components = srcBucket.split('.');
	var dstBucket = "";
	for (i = 0; i < components.length - 1; i++) { 
    	dstBucket += components[i] + ".";
	}
	dstBucket += "thumbnails";


	console.log("Source bucket name:\n", srcBucket);
	console.log("Destination bucket name:\n", dstBucket);

    // Object key may have spaces or unicode non-ASCII characters.
    var srcKey    = decodeURIComponent(event.Records[0].s3.object.key.replace(/\+/g, " "));  
    var dstKey    = "thumbnail-" + srcKey;

	console.log("Source file name:\n", srcKey);
	console.log("Destination file name:\n", dstKey);

    // source and destination buckets must not be the same.
    if (srcBucket == dstBucket) {
        callback("Source and destination buckets must not be the same.");
        return;
    }

    // Infer the image type.
    var typeMatch = srcKey.match(/\.([^.]*)$/);
    if (!typeMatch) {
        callback("Unknown image type.");
        return;
    }

    var imageType = typeMatch[1];
    if (imageType != "png") {
        callback('Unsupported image type: ${imageType}');
        return;
    }

    // Download the image from S3, 
    // transform, 
    // and upload to a different S3 bucket.
    async.waterfall([

        function download(next) {
            s3.getObject({
                    Bucket: srcBucket,
                    Key: srcKey
                },
            next);
        },

        function transform(response, next) {
        
            gm(response.Body).size(function(err, size) {
                
                // compute dimensions of scaled image
                var scalingFactor = Math.min(
                    MAX_WIDTH / size.width,
                    MAX_HEIGHT / size.height
                );
                var width  = scalingFactor * size.width;
                var height = scalingFactor * size.height;

                // scale the image
                this.resize(width, height)
                    .toBuffer(imageType, function(err, buffer) {
                        if (err) {
                            next(err);
                        } else {
                            next(null, response.ContentType, buffer);
                        }
                    });
            });
        },

        function upload(contentType, data, next) {
            // save the scaled image
            s3.putObject({
                    Bucket: dstBucket,
                    Key: dstKey,
                    Body: data,
                    ContentType: contentType
                }, next);
        }], 
        
        function (err) {
            if (err) {
                console.error('Error: ' + err);
            } else {
                console.log('Successfully created ' + dstKey);
            }

            callback(null, "function finished execution.");
        }
    );
};

