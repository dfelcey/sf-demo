/**
 * AgentGetMenuItemsActions
 *
 * Retrieves menu items for a selected menu or storefront.
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentGetMenuItemsActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Menu Id'
            description='The Menu__c record Id to retrieve items for. If provided, storefrontId is ignored.'
            required=false
        )
        public Id menuId;

        @InvocableVariable(
            label='Storefront Id'
            description='The Storefront__c record Id to retrieve all menu items for (across all menus). Used only if menuId is not provided.'
            required=false
        )
        public Id storefrontId;
    }

    public class MenuItemSummary {
        @InvocableVariable(label='Menu Item Id' description='The Menu_Item__c record Id.')
        public Id id;

        @InvocableVariable(label='Name' description='The menu item name (Menu_Item__c.Name).')
        public String name;

        @InvocableVariable(label='Description' description='Menu item description (Menu_Item__c.Description__c).')
        public String description;

        @InvocableVariable(label='Price' description='Item price (Menu_Item__c.Price__c).')
        public Decimal price;

        @InvocableVariable(label='Calories' description='Calorie count (Menu_Item__c.Calories__c).')
        public Decimal calories;

        @InvocableVariable(label='Available' description='Whether the item is currently available (Menu_Item__c.Available__c).')
        public Boolean available;

        @InvocableVariable(label='Image URL' description='Image URL for the item (Menu_Item__c.Image_URL__c).')
        public String imageUrl;

        @InvocableVariable(label='Menu Id' description='The parent Menu__c Id.')
        public Id menuId;

        @InvocableVariable(label='Menu Name' description='The parent menu name.')
        public String menuName;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the query executed successfully.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Menu Items'
            description='A list of menu items matching the query.'
        )
        public List<MenuItemSummary> menuItems;

        @InvocableVariable(
            label='Menu Items JSON'
            description='JSON-serialized version of menu items for clients that prefer JSON parsing.'
        )
        public String menuItemsJson;

        @InvocableVariable(
            label='Item Count'
            description='Number of menu items found.'
        )
        public Integer itemCount;
    }

    @InvocableMethod(
        label='Get Menu Items'
        description='Retrieves menu items for a selected menu or all items for a storefront. Requires accountId for security.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.menuItems = new List<MenuItemSummary>();
        out.success = false;
        out.message = null;
        out.itemCount = 0;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;

        try {
            if (req == null || req.accountId == null) {
                out.message = 'accountId is required.';
                out.menuItemsJson = JSON.serialize(out.menuItems);
                return new List<Response>{ out };
            }
            if (req.menuId == null && req.storefrontId == null) {
                out.message = 'Either menuId or storefrontId is required.';
                out.menuItemsJson = JSON.serialize(out.menuItems);
                return new List<Response>{ out };
            }

            // Validate ownership based on which ID was provided
            if (req.menuId != null) {
                // Validate menu belongs to a storefront owned by this account
                List<Menu__c> menus = [
                    SELECT Id, Storefront__r.Account__c
                    FROM Menu__c
                    WHERE Id = :req.menuId
                    LIMIT 1
                ];
                if (menus.isEmpty()) {
                    out.message = 'No menu found with the provided Id.';
                    out.menuItemsJson = JSON.serialize(out.menuItems);
                    return new List<Response>{ out };
                }
                if (menus[0].Storefront__r.Account__c != req.accountId) {
                    out.message = 'Access denied. This menu does not belong to the specified account.';
                    out.menuItemsJson = JSON.serialize(out.menuItems);
                    return new List<Response>{ out };
                }
            } else {
                // Validate storefront belongs to this account
                List<Storefront__c> storefronts = [
                    SELECT Id, Account__c
                    FROM Storefront__c
                    WHERE Id = :req.storefrontId
                    LIMIT 1
                ];
                if (storefronts.isEmpty()) {
                    out.message = 'No storefront found with the provided Id.';
                    out.menuItemsJson = JSON.serialize(out.menuItems);
                    return new List<Response>{ out };
                }
                if (storefronts[0].Account__c != req.accountId) {
                    out.message = 'Access denied. This storefront does not belong to the specified account.';
                    out.menuItemsJson = JSON.serialize(out.menuItems);
                    return new List<Response>{ out };
                }
            }

            List<Menu_Item__c> items;

            if (req.menuId != null) {
                items = [
                    SELECT Id, Name, Description__c, Price__c, Calories__c, Available__c, Image_URL__c,
                           Menu__c, Menu__r.Name
                    FROM Menu_Item__c
                    WHERE Menu__c = :req.menuId
                    ORDER BY Name ASC
                    LIMIT 200
                ];
            } else {
                items = [
                    SELECT Id, Name, Description__c, Price__c, Calories__c, Available__c, Image_URL__c,
                           Menu__c, Menu__r.Name
                    FROM Menu_Item__c
                    WHERE Menu__r.Storefront__c = :req.storefrontId
                    ORDER BY Menu__r.Name ASC, Name ASC
                    LIMIT 200
                ];
            }

            for (Menu_Item__c item : items) {
                MenuItemSummary s = new MenuItemSummary();
                s.id = item.Id;
                s.name = item.Name;
                s.description = item.Description__c;
                s.price = item.Price__c;
                s.calories = item.Calories__c;
                s.available = item.Available__c;
                s.imageUrl = item.Image_URL__c;
                s.menuId = item.Menu__c;
                s.menuName = item.Menu__r.Name;
                out.menuItems.add(s);
            }

            out.itemCount = out.menuItems.size();
            out.success = true;
            out.message = out.itemCount + ' menu item(s) found.';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        out.menuItemsJson = JSON.serialize(out.menuItems);
        return new List<Response>{ out };
    }
}