#include "edge_detector.hpp"

#include <opencv2/opencv.hpp>
#include <opencv2/imgproc/types_c.h>

using namespace cv;
using namespace std;

// helper function:
// finds a cosine of angle between vectors
// from pt0->pt1 and from pt0->pt2
double EdgeDetector::get_cosine_angle_between_vectors(cv::Point pt1, cv::Point pt2, cv::Point pt0)
{
    double dx1 = pt1.x - pt0.x;
    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10);
}

vector<cv::Point> image_to_vector(Mat& image)
{
    int imageWidth = image.size().width;
    int imageHeight = image.size().height;

    return {
        cv::Point(0, 0),
        cv::Point(imageWidth, 0),
        cv::Point(0, imageHeight),
        cv::Point(imageWidth, imageHeight)
    };
}

vector<cv::Point> EdgeDetector::detect_edges(Mat& image)
{
    vector<vector<cv::Point>> squares = find_squares(image);
    vector<cv::Point>* biggestSquare = NULL;

    // Sort so that the points are ordered clockwise

    struct sortY {
        bool operator() (cv::Point pt1, cv::Point pt2) { return (pt1.y < pt2.y);}
    } orderRectangleY;
    struct sortX {
        bool operator() (cv::Point pt1, cv::Point pt2) { return (pt1.x < pt2.x);}
    } orderRectangleX;

    for (int i = 0; i < squares.size(); i++) {
        vector<cv::Point>* currentSquare = &squares[i];

        std::sort(currentSquare->begin(),currentSquare->end(), orderRectangleY);
        std::sort(currentSquare->begin(),currentSquare->begin()+2, orderRectangleX);
        std::sort(currentSquare->begin()+2,currentSquare->end(), orderRectangleX);

        float currentSquareWidth = get_width(*currentSquare);
        float currentSquareHeight = get_height(*currentSquare);

        if (currentSquareWidth < image.size().width / 5 || currentSquareHeight < image.size().height / 5) {
            continue;
        }

        if (currentSquareWidth > image.size().width * 0.99 || currentSquareHeight > image.size().height * 0.99) {
            continue;
        }

        if (biggestSquare == NULL) {
            biggestSquare = currentSquare;
            continue;
        }

        float biggestSquareWidth = get_width(*biggestSquare);
        float biggestSquareHeight = get_height(*biggestSquare);

        if (currentSquareWidth * currentSquareHeight >= biggestSquareWidth * biggestSquareHeight) {
            biggestSquare = currentSquare;
        }

    }

    if (biggestSquare == NULL) {
        return {
            cv::Point(0, 0),
            cv::Point(0, 0),
            cv::Point(0, 0),
            cv::Point(0, 0)};
    }

    std::sort(biggestSquare->begin(),biggestSquare->end(), orderRectangleY);
    std::sort(biggestSquare->begin(),biggestSquare->begin()+2, orderRectangleX);
    std::sort(biggestSquare->begin()+2,biggestSquare->end(), orderRectangleX);

    return *biggestSquare;
}

float EdgeDetector::get_height(vector<cv::Point>& square) {
    float upperLeftToLowerRight = square[3].y - square[0].y;
    float upperRightToLowerLeft = square[1].y - square[2].y;

    return max(upperLeftToLowerRight, upperRightToLowerLeft);
}

float EdgeDetector::get_width(vector<cv::Point>& square) {
    float upperLeftToLowerRight = square[3].x - square[0].x;
    float upperRightToLowerLeft = square[1].x - square[2].x;

    return max(upperLeftToLowerRight, upperRightToLowerLeft);
}

cv::Mat EdgeDetector::debug_squares( cv::Mat image )
{

    Mat gray0(image.size(), CV_8U), gray;
    cvtColor(image, gray, COLOR_BGR2GRAY);
    // CLAHEを適用
    // EdgeDetector::apply_CLAHE(gray, gray);
    medianBlur(gray, gray, 11); // blur will enhance edge detection
    int thresholdLevel = 130;
    Canny(gray, gray0, thresholdLevel, thresholdLevel * 3, 3);
    dilate(gray0, gray0, Mat(), Point(-1, -1));

    cvtColor(gray0, gray0, COLOR_GRAY2BGR);

    vector<vector<cv::Point>> squares = find_squares(image);
    for (const auto & square : squares) {
        // draw rotated rect
        cv::RotatedRect minRect = minAreaRect(cv::Mat(square));
        cv::Point2f rect_points[4];
        minRect.points( rect_points );
        for ( int j = 0; j < 4; j++ ) {
            cv::line(gray0, rect_points[j], rect_points[(j + 1) % 4], cv::Scalar(255, 0, 0), 1, 8); // blue
        }
    }

    return gray0;
}

vector<vector<cv::Point> > EdgeDetector::find_squares(Mat& image)
{
    vector<int> usedThresholdLevel;
    vector<vector<Point> > squares;

    Mat bluredImage(image.size(), CV_8U), edgeImage(image.size(), CV_8U), gray;

    cvtColor(image , gray, COLOR_BGR2GRAY);
    // CLAHEを適用すると精度が低下するから削除
    // EdgeDetector::apply_CLAHE(gray, gray);
    vector<vector<cv::Point> > contours;

    int blurLevels[] = {5, 11, 15, 21};
    int thresholdLevels[] = {50, 70, 90, 110, 130};
    for (int blurLevel : blurLevels) {
        medianBlur(gray, bluredImage, blurLevel); // blur will enhance edge detection
        for(int thresholdLevel : thresholdLevels) {
            Canny(bluredImage, edgeImage, thresholdLevel, thresholdLevel * 3, 3);

            dilate(edgeImage, edgeImage, Mat(), Point(-1, -1));

            findContours(edgeImage, contours, CV_RETR_LIST, CV_CHAIN_APPROX_SIMPLE);

            vector<Point> approx;
            for (const auto & contour : contours) {
                approxPolyDP(Mat(contour), approx, arcLength(Mat(contour), true) * 0.02, true);

                if (approx.size() == 4 && fabs(contourArea(Mat(approx))) > 1000 &&
                    isContourConvex(Mat(approx))) {
                    double maxCosine = 0;

                    for (int j = 2; j < 5; j++) {
                        double cosine = fabs(get_cosine_angle_between_vectors(approx[j % 4], approx[j - 2], approx[j - 1]));
                        maxCosine = MAX(maxCosine, cosine);
                    }

                    if (maxCosine < 0.3) {
                        squares.push_back(approx);
                        usedThresholdLevel.push_back(thresholdLevel);
                    }
                }
            }
        }
    }

    return squares;
}

void EdgeDetector::apply_CLAHE(cv::Mat &src, cv::Mat &dst)
{
    // グレースケール画像へ変換（必要な場合）
    cv::Mat gray;
    if (src.channels() == 3)
    {
        cvtColor(src, gray, COLOR_BGR2GRAY);
    }
    else
    {
        gray = src.clone();
    }

    // CLAHEオブジェクトの生成
    Ptr<CLAHE> clahe = createCLAHE();
    clahe->setClipLimit(2.0);            // クリップリミットの設定
    clahe->setTilesGridSize(Size(8, 8)); // タイルのグリッドサイズを設定

    // CLAHEを適用
    clahe->apply(gray, dst);
}
