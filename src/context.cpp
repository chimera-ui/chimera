// Copyright 2017 Dan Ristic

#include "src/context.h"

#include <string>

#include "src/core.h"
#include "src/adaptor/adaptor.h"
#include "src/element.h"
#include "src/document.h"
#include "src/rendering.h"

namespace Chimera {
    Context::Context()
        : document{*this}
        , mMouseX{0}
        , mMouseY{0}
        , mAdaptor{}
    {
        mAdaptor = std::make_shared<Adaptor>();
        mRenderer = std::make_unique<Renderer>(mAdaptor.get());
    }

    Context::~Context() { }

    void Context::update(double dt) {
        CHIMERA_UNUSED(dt);
    }

    void Context::addInputCharacters(std::string characters) {
        TextInputEvent event{characters};
        document.body->handleEvent(dynamic_cast<Event*>(&event));
    }

    void Context::setKeyPress(KeyType key) {
        KeyEvent event{key};
        document.body->handleEvent(dynamic_cast<Event*>(&event));
    }

    void Context::setMousePosition(int x, int y) {
        document.setCursorType(CursorType::Arrow);

        // if (x != mMouseX || y != mMouseY) {
            MouseMoveEvent event{x, y};
            document.body->handleEvent(dynamic_cast<Event*>(&event));
        // }

        mMouseX = x;
        mMouseY = y;
    }

    void Context::setScrollDirection(int direction) {
        mScrollDirection = direction;

        MouseScrollEvent event{direction, mMouseX, mMouseY};
        document.body->handleEvent(dynamic_cast<Event*>(&event));
    }

    Vec2 Context::getMousePosition() {
        Vec2 position{static_cast<float>(mMouseX), static_cast<float>(mMouseY)};
        return position;
    }

    void Context::setMouseDown() {
        MouseDownEvent event{mMouseX, mMouseY};
        bool bubbled = document.body->handleEvent(dynamic_cast<Event*>(&event));

        if (bubbled) {
            document.focusManager.focusedElement = nullptr;
        }
    }

    void Context::setDoubleClick()
    {
        Event event{EventType::DoubleClick};

        document.body->handleEvent(&event);
    }

    void Context::useAdaptor(std::shared_ptr<Adaptor> adaptor) {
        mAdaptor = adaptor;
        mRenderer->setAdaptor(mAdaptor.get());
    }

    std::unique_ptr<ImageRef> Context::loadImage(
        std::string name, int& width, int& height)
    {
        return mAdaptor->loadImage(name, width, height);
    }

    unsigned int Context::loadTexture(
        unsigned int width, unsigned int height, unsigned char* buffer)
    {
        return mAdaptor->loadTexture(width, height, buffer);
    }

    void Context::loadFont(std::string name, std::string location)
    {
        mRenderer->getFontManager()->loadFont(name, location);
    }

    void Context::render(float dt) {
        CHIMERA_UNUSED(dt);

        // TODO: Push this into renderer and cache it
        DrawData data;

        data.width = document.getWidth();
        data.height = document.getHeight();
        data.screenWidth = document.getScreenWidth();
        data.screenHeight = document.getScreenHeight();

        data.renderer = mRenderer.get();

        if (document.body != nullptr) {
            document.body->render(&data);
        }

        if (mAdaptor) {
            mAdaptor->renderCallback(&data);
        }
    }
}  // namespace Chimera
