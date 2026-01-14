/**
 * AgentGetActiveMenusActions
 *
 * Retrieves all active menus for a given storefront.
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentGetActiveMenusActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Storefront Id'
            description='The Storefront__c record Id to retrieve menus for.'
            required=true
        )
        public Id storefrontId;
    }

    public class MenuSummary {
        @InvocableVariable(label='Menu Id' description='The Menu__c record Id.')
        public Id id;

        @InvocableVariable(label='Name' description='The menu name (Menu__c.Name).')
        public String name;

        @InvocableVariable(label='Display Name' description='The menu display name (Menu__c.Menu_Display_Name__c).')
        public String displayName;

        @InvocableVariable(label='Description' description='Menu description (Menu__c.Description__c).')
        public String description;

        @InvocableVariable(label='Active' description='Whether the menu is active (Menu__c.Active__c).')
        public Boolean active;
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
            label='Menus'
            description='A list of active menus for the storefront.'
        )
        public List<MenuSummary> menus;

        @InvocableVariable(
            label='Menus JSON'
            description='JSON-serialized version of menus for clients that prefer JSON parsing.'
        )
        public String menusJson;

        @InvocableVariable(
            label='Menu Count'
            description='Number of active menus found.'
        )
        public Integer menuCount;
    }

    @InvocableMethod(
        label='Get Active Menus'
        description='Retrieves all active menus for a given storefront. Requires accountId for security.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.menus = new List<MenuSummary>();
        out.success = false;
        out.message = null;
        out.menuCount = 0;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;

        try {
            if (req == null || req.accountId == null) {
                out.message = 'accountId is required.';
                out.menusJson = JSON.serialize(out.menus);
                return new List<Response>{ out };
            }
            if (req.storefrontId == null) {
                out.message = 'storefrontId is required.';
                out.menusJson = JSON.serialize(out.menus);
                return new List<Response>{ out };
            }

            // Validate storefront belongs to the provided account
            List<Storefront__c> storefronts = [
                SELECT Id, Account__c
                FROM Storefront__c
                WHERE Id = :req.storefrontId
                LIMIT 1
            ];

            if (storefronts.isEmpty()) {
                out.message = 'No storefront found with the provided Id.';
                out.menusJson = JSON.serialize(out.menus);
                return new List<Response>{ out };
            }

            if (storefronts[0].Account__c != req.accountId) {
                out.message = 'Access denied. This storefront does not belong to the specified account.';
                out.menusJson = JSON.serialize(out.menus);
                return new List<Response>{ out };
            }

            List<Menu__c> menus = [
                SELECT Id, Name, Menu_Display_Name__c, Description__c, Active__c
                FROM Menu__c
                WHERE Storefront__c = :req.storefrontId
                AND Active__c = true
                ORDER BY Name ASC
                LIMIT 100
            ];

            for (Menu__c m : menus) {
                MenuSummary s = new MenuSummary();
                s.id = m.Id;
                s.name = m.Name;
                s.displayName = m.Menu_Display_Name__c;
                s.description = m.Description__c;
                s.active = m.Active__c;
                out.menus.add(s);
            }

            out.menuCount = out.menus.size();
            out.success = true;
            out.message = out.menuCount + ' active menu(s) found.';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        out.menusJson = JSON.serialize(out.menus);
        return new List<Response>{ out };
    }
}