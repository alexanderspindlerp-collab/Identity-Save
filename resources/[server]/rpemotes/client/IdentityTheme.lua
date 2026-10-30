--- Identity dark-glass + teal accent for NativeUI menus
IdentityTheme = {}

local function stripGtaFormatting(text)
    if not text or text == '' then return text end
    text = text:gsub('~%a~%d?', '')
    text = text:gsub('<[^>]+>', '')
    return text
end

IdentityTheme.StripGtaFormatting = stripGtaFormatting

local function styleMenu(menu)
    if not menu or menu() ~= 'UIMenu' then return end

    menu.Title:Text('')
    menu.Title:Colour(0, 0, 0, 0)

    if menu.Subtitle and menu.Subtitle.Rectangle then
        menu.Subtitle.Rectangle:Colour(8, 12, 18, 240)
        menu.Subtitle.Text:Colour(238, 242, 246, 255)
    end

    if menu.Description and menu.Description.Bar then
        menu.Description.Bar:Colour(0, 248, 185, 255)
    end

    if menu.Description and menu.Description.Text then
        menu.Description.Text:Colour(200, 210, 220, 255)
    end

    if menu.Extra and menu.Extra.Up then
        menu.Extra.Up:Colour(8, 12, 18, 220)
        menu.Extra.Down:Colour(8, 12, 18, 220)
    end
end

local function styleItem(item)
    if not item or not item.Rectangle then return end
    item.Rectangle:Colour(12, 18, 26, 180)
end

function IdentityTheme.ApplyPool(pool)
    if not pool or not pool.Menus then return end

    for _, menu in pairs(pool.Menus) do
        styleMenu(menu)
        if menu.Items then
            for _, item in ipairs(menu.Items) do
                if item.Rectangle then
                    styleItem(item)
                elseif item.Base and item.Base.Rectangle then
                    styleItem(item.Base)
                end
            end
        end
    end
end

function IdentityTheme.ApplyMenu(menu)
    styleMenu(menu)
end
