// Copyright 2017 Dan Ristic

#import <Cocoa/Cocoa.h>

#include <string>
#include <functional>
#include <chrono>

#include "Chimera/Chimera.h"

#include "src/adaptor/opengl3.h"
#include "app/root.h"

#ifdef _WIN32
    #include <Windows.h>
#endif

using namespace std::placeholders;

// from: http://stackoverflow.com/questions/19968705/unsigned-integer-as-utf-8-value
std::string UnicodeToUTF8(unsigned int codepoint)
{
    std::string out;

    if (codepoint <= 0x7f)
        out.append(1, static_cast<char>(codepoint));
    else if (codepoint <= 0x7ff)
    {
        out.append(1, static_cast<char>(0xc0 | ((codepoint >> 6) & 0x1f)));
        out.append(1, static_cast<char>(0x80 | (codepoint & 0x3f)));
    }
    else if (codepoint <= 0xffff)
    {
        out.append(1, static_cast<char>(0xe0 | ((codepoint >> 12) & 0x0f)));
        out.append(1, static_cast<char>(0x80 | ((codepoint >> 6) & 0x3f)));
        out.append(1, static_cast<char>(0x80 | (codepoint & 0x3f)));
    }
    else
    {
        out.append(1, static_cast<char>(0xf0 | ((codepoint >> 18) & 0x07)));
        out.append(1, static_cast<char>(0x80 | ((codepoint >> 12) & 0x3f)));
        out.append(1, static_cast<char>(0x80 | ((codepoint >> 6) & 0x3f)));
        out.append(1, static_cast<char>(0x80 | (codepoint & 0x3f)));
    }
    return out;
}

class GLFWapplication {
 public:
    static void initialize(GLFWwindow* window, Chimera::Context* context) {
        mContext = context;

        glfwSetErrorCallback(errorCallback);
        glfwSetScrollCallback(window, scrollCallback);
        glfwSetMouseButtonCallback(window, mouseButtonCallback);
        glfwSetCursorPosCallback(window, cursorPositionCallback);
        glfwSetCharCallback(window, characterCallback);
        glfwSetKeyCallback(window, keyCallback);
    }

    static void errorCallback(int error, const char* description) {
        CHIMERA_UNUSED(error);

        fprintf(stderr, "Error: %s\n", description);
    }

    static void scrollCallback(GLFWwindow* window, double xOffset, double yOffset) {
        CHIMERA_UNUSED(window);
        CHIMERA_UNUSED(xOffset);

        int direction = 0;

        if (yOffset > 0) {
            direction = 1;
        } else if (yOffset < 0) {
            direction = -1;
        }

        mContext->setScrollDirection(direction);
    }

    static void mouseButtonCallback(GLFWwindow* window, int button, int action, int mods) {
        CHIMERA_UNUSED(window);
        CHIMERA_UNUSED(mods);

        double interval = [NSEvent doubleClickInterval] * 1000; // in ms

        if (button == GLFW_MOUSE_BUTTON_LEFT && action == GLFW_PRESS)
        {
            mContext->setMouseDown();

            auto now = std::chrono::system_clock::now();
            auto delta = std::chrono::duration<double, std::milli>(
                now - mLastClick).count();

            if (delta < interval)
            {
                mContext->setDoubleClick();
            }

            mLastClick = now;

            if (mods == GLFW_MOD_CONTROL)
            {
                NSEvent *event = [NSApp currentEvent];

                NSMenu *theMenu = [NSApp windowsMenu];
                [NSMenu popUpContextMenu:theMenu withEvent:event forView:[[event window] contentView]];
            }
        }
    }

    static void cursorPositionCallback(GLFWwindow* window, double x, double y) {
        int focused = glfwGetWindowAttrib(window, GLFW_FOCUSED);
        if (focused) {
            mContext->setMousePosition(x, y);
        } else {
            mContext->setMousePosition(-1, -1);
        }
    }

    static void characterCallback(GLFWwindow* window, unsigned int codepoint) {
        CHIMERA_UNUSED(window);

        std::string text = UnicodeToUTF8(codepoint);

        mContext->addInputCharacters(text);
    }

    static void keyCallback(GLFWwindow* window, int key, int scancode, int action, int mods) {
        CHIMERA_UNUSED(window);
        CHIMERA_UNUSED(scancode);
        CHIMERA_UNUSED(mods);

        if (key == GLFW_KEY_BACKSPACE && (action == GLFW_PRESS || action == GLFW_REPEAT)) {
            mContext->setKeyPress(Chimera::KeyType::Backspace);
        }

        if (key == GLFW_KEY_TAB && action == GLFW_PRESS)
        {
            mContext->setKeyPress(Chimera::KeyType::Tab);
        }
    }

 private:
    GLFWapplication() { }
    GLFWapplication(GLFWapplication const&);
    void operator=(GLFWapplication const&);

    static Chimera::Context* mContext;
    static std::chrono::system_clock::time_point mLastClick;
};

Chimera::Context* GLFWapplication::mContext{nullptr};

std::chrono::system_clock::time_point GLFWapplication::mLastClick{};

#ifdef _WIN32
int CALLBACK WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
#else
int main() {
#endif
    const int WIDTH = 1280;
    const int HEIGHT = 720;

    Chimera::Context context;
    Chimera::Document& document = context.document;

    printf("Starting...!\n");

#ifdef _WIN32
    glewInit();
#endif

    GLFWwindow* window;

    /* Initialize the library */
    if (!glfwInit()) {
        return -1;
    }

    /* Create a windowed mode window and its OpenGL context */
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_DECORATED, GL_FALSE);
    window = glfwCreateWindow(WIDTH, HEIGHT, "Chimera", nullptr, nullptr);
    if (!window)
    {
        glfwTerminate();
        return -1;
    }

    GLFWmonitor* primary = glfwGetPrimaryMonitor();
    const GLFWvidmode* mode = glfwGetVideoMode(primary);

    int centerX = (mode->width - WIDTH) / 2;
    int centerY = (mode->height - HEIGHT) / 2;
    glfwSetWindowPos(window, centerX, centerY);

    GLFWapplication::initialize(window, &context);

    /* Make the window's context current */
    glfwMakeContextCurrent(window);

    document.setDimensions(WIDTH, HEIGHT);

    auto adaptor = std::make_shared<Chimera::OpenGL3Bridge>();
    context.useAdaptor(adaptor);

    context.loadFont("Noto", "assets/NotoEmoji-Regular.ttf");
    context.loadFont("Roboto", "assets/Roboto-Regular.ttf");
    context.loadFont("Roboto Thin", "assets/Roboto-Thin.ttf");

    // Load the system default font
    context.loadFont("system", "/System/Library/Fonts/LucidaGrande.ttc");

    document.body->append(document.createElement<AppElement>());

    GLFWcursor* arrowCursor = glfwCreateStandardCursor(GLFW_ARROW_CURSOR);
    GLFWcursor* handCursor = glfwCreateStandardCursor(GLFW_HAND_CURSOR);
    GLFWcursor* ibeamCursor = glfwCreateStandardCursor(GLFW_IBEAM_CURSOR);

    double lastTime = glfwGetTime();
    int frames = 0;

    glfwSwapInterval(1);

    /* Loop until the user closes the window */
    while (!glfwWindowShouldClose(window))
    {
        // Measure speed
        double currentTime = glfwGetTime();
        frames++;
        if (currentTime - lastTime >= 1.0) {
            printf("%f ms/frame\n", 1000.0/double(frames));
            frames = 0;
            lastTime += 1.0;
        }

        int width, height;
        glfwGetFramebufferSize(window, &width, &height);
        document.setScreenDimensions(width, height);

        context.update(16);
        context.render(16);

        Chimera::CursorType cursor = document.getCursorType();
        switch(cursor) {
        case Chimera::CursorType::Arrow:
        {
            glfwSetCursor(window, arrowCursor);
            break;
        }
        case Chimera::CursorType::Hand:
        {
            glfwSetCursor(window, handCursor);
            break;
        }
        case Chimera::CursorType::IBeam:
        {
            glfwSetCursor(window, ibeamCursor);
            break;
        }
        }

        /* Swap front and back buffers */
        glfwSwapBuffers(window);

        /* Poll for and process events */
        glfwPollEvents();
    }

    glfwDestroyCursor(ibeamCursor);

    glfwTerminate();

    return 0;
}
