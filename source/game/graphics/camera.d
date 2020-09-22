module game.graphics.camera;

import game.common, game.core, game.graphics;

final class Camera
{
    private
    {
        mat4f _view = mat4f.identity;
    }

    void move(vec2f amount)
    {
        this._view.translate(vec3f(amount, 0));
    }

    void lookAt(vec2f point)
    {
        const size         = Window.size;
        const topLeft      = point - (size / vec2f(2));
        this._view.c[0][3] = topLeft.x;
        this._view.c[1][3] = topLeft.y;
    }

    @property
    mat4f view()
    {
        return this._view;
    }
}