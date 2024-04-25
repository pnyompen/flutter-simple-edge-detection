#include <stdint.h>
#include <stdlib.h>
#include <opencv2/opencv.hpp>
#include "native_edge_detection.hpp"
#include "edge_detector.hpp"
#include "image_processor.hpp"


extern "C" __attribute__((visibility("default"))) __attribute__((used))
struct Coordinate *create_coordinate(double x, double y)
{
    struct Coordinate *coordinate = (struct Coordinate *)malloc(sizeof(struct Coordinate));
    coordinate->x = x;
    coordinate->y = y;
    return coordinate;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
struct DetectionResult *create_detection_result(Coordinate *topLeft, Coordinate *topRight, Coordinate *bottomLeft, Coordinate *bottomRight)
{
    struct DetectionResult *detectionResult = (struct DetectionResult *)malloc(sizeof(struct DetectionResult));
    detectionResult->topLeft = topLeft;
    detectionResult->topRight = topRight;
    detectionResult->bottomLeft = bottomLeft;
    detectionResult->bottomRight = bottomRight;
    return detectionResult;
}

extern "C" __attribute__((visibility("default"))) __attribute__((used)) struct DetectionResult *detect_edges(uint8_t *data, int32_t width, int32_t height)
{
    // 検出に失敗したああ場合は、座標を0に設定する
    struct DetectionResult *coordinate = (struct DetectionResult *)malloc(sizeof(struct DetectionResult));
    cv::Mat mat(height, width, CV_8UC3, data); // Assuming the image is in RGB format

    if (mat.size().width == 0 || mat.size().height == 0) {
        return create_detection_result(
            create_coordinate(0, 0),
            create_coordinate(0, 0),
            create_coordinate(0, 0),
            create_coordinate(0, 0)
        );
    }


    vector<cv::Point> points = EdgeDetector::detect_edges(mat);

    return create_detection_result(
        create_coordinate((double)points[0].x / mat.size().width, (double)points[0].y / mat.size().height),
        create_coordinate((double)points[1].x / mat.size().width, (double)points[1].y / mat.size().height),
        create_coordinate((double)points[2].x / mat.size().width, (double)points[2].y / mat.size().height),
        create_coordinate((double)points[3].x / mat.size().width, (double)points[3].y / mat.size().height)
    );
}

extern "C" __attribute__((visibility("default"))) __attribute__((used))
bool process_image(
    char *path,
    double topLeftX,
    double topLeftY,
    double topRightX,
    double topRightY,
    double bottomLeftX,
    double bottomLeftY,
    double bottomRightX,
    double bottomRightY
) {
    cv::Mat mat = cv::imread(path);

    cv::Mat resizedMat = ImageProcessor::crop_and_transform(
        mat,
        topLeftX * mat.size().width,
        topLeftY * mat.size().height,
        topRightX * mat.size().width,
        topRightY * mat.size().height,
        bottomLeftX * mat.size().width,
        bottomLeftY * mat.size().height,
        bottomRightX * mat.size().width,
        bottomRightY * mat.size().height
    );

    return cv::imwrite(path, resizedMat);
}