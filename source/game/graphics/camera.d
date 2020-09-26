module game.graphics.camera;

import game.common, game.core, game.graphics;

final class Camera
{
    private
    {
        mat4f _view = mat4f.identity;
        box2f _constrain;
    }

    void move(vec2f amount)
    {
        this._view.translate(vec3f(amount, 0));
        this.constrainView();
    }

    void lookAt(vec2f point)
    {
        const topLeft      = (this.size / vec2f(2)) - point;
        this._view.c[0][3] = topLeft.x;
        this._view.c[1][3] = topLeft.y;

        this.constrainView();
    }

    private void constrainView()
    {
        if(this._constrain.isNaN)
            return;

        const topLeft  = -vec2f(this._view.c[0][3], this._view.c[1][3]);
        const botRight = topLeft + this.size;

        // Start with the max bounds, so we can constrain things to the top-left of the constraint in the event that the constraint is smaller than
        // our camera size.
        vec2f newTopLeft = topLeft;
        if(botRight.x > this._constrain.max.x)
            newTopLeft.x = this._constrain.max.x - this.size.x;
        if(botRight.y > this._constrain.max.y)
            newTopLeft.y = this._constrain.max.y - this.size.y;

        // Now we can do this.
        if(newTopLeft.x < this._constrain.min.x)
            newTopLeft.x = this._constrain.min.x;
        if(newTopLeft.y < this._constrain.min.y)
            newTopLeft.y = this._constrain.min.y;

        this._view.c[0][3] = -newTopLeft.x;
        this._view.c[1][3] = -newTopLeft.y;
    }

    @property
    vec2f size()
    {
        return vec2f(Window.size); // Really doubt I'll ever need a camera that isn't screen-sized, but we'll support the possiblity anyway by going through this property.
    }

    @property
    void constrainBox(box2f box)
    {
        this._constrain = box;
    }

    @property
    box2f contrainBox()
    {
        return this._constrain;
    }

    @property
    mat4f view()
    {
        return this._view;
    }
}