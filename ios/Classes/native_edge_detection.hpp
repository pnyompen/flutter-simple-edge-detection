struct Coordinate
{
    double x;
    double y;
};

struct DetectionResult
{
    Coordinate* topLeft;
    Coordinate* topRight;
    Coordinate* bottomLeft;
    Coordinate* bottomRight;
};

extern "C"
struct ProcessingInput
{
    char* path;
    DetectionResult detectionResult;
};

struct DebugSquaresResult
{
    uint8_t* data;
    int32_t width;
    int32_t height;
};

extern "C"
struct DetectionResult *detect_edges(uint8_t *data, int32_t width, int32_t height);

extern "C"
bool process_image(
    char* path,
    double topLeftX,
    double topLeftY,
    double topRightX,
    double topRightY,
    double bottomLeftX,
    double bottomLeftY,
    double bottomRightX,
    double bottomRightY
);