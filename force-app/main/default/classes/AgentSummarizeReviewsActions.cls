/**
 * AgentSummarizeReviewsActions
 *
 * Retrieves recent reviews for a storefront and provides summary statistics.
 * The AI can use this output to generate insights about customer sentiment.
 * Requires accountId for security validation.
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return
 * a single Response row.
 */
public with sharing class AgentSummarizeReviewsActions {
    public class Request {
        @InvocableVariable(
            label='Account Id'
            description='The Account Id that owns the storefront. Required for security validation.'
            required=true
        )
        public Id accountId;

        @InvocableVariable(
            label='Storefront Id'
            description='The Storefront__c record Id to retrieve reviews for.'
            required=true
        )
        public Id storefrontId;

        @InvocableVariable(
            label='Days Back'
            description='Number of days to look back for reviews. Defaults to 30 if not provided.'
            required=false
        )
        public Integer daysBack;

        @InvocableVariable(
            label='Limit'
            description='Maximum number of reviews to retrieve. Defaults to 20 if not provided.'
            required=false
        )
        public Integer reviewLimit;
    }

    public class ReviewSummary {
        @InvocableVariable(label='Review Id' description='The Review__c record Id.')
        public Id id;

        @InvocableVariable(label='Rating' description='Star rating (1-5).')
        public Decimal rating;

        @InvocableVariable(label='Comments' description='Review comments text.')
        public String comments;

        @InvocableVariable(label='Customer Id' description='The Customer (Contact) Id who left the review.')
        public Id customerId;

        @InvocableVariable(label='Order Date' description='Date of the order associated with the review.')
        public Date orderDate;

        @InvocableVariable(label='Status' description='Review status.')
        public String status;
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
            label='Reviews'
            description='List of recent reviews.'
        )
        public List<ReviewSummary> reviews;

        @InvocableVariable(
            label='Reviews JSON'
            description='JSON-serialized version of reviews for clients that prefer JSON parsing.'
        )
        public String reviewsJson;

        @InvocableVariable(
            label='Review Count'
            description='Number of reviews returned.'
        )
        public Integer reviewCount;

        @InvocableVariable(
            label='Average Rating'
            description='Average star rating across the returned reviews.'
        )
        public Decimal averageRating;

        @InvocableVariable(
            label='Five Star Count'
            description='Number of 5-star reviews.'
        )
        public Integer fiveStarCount;

        @InvocableVariable(
            label='Four Star Count'
            description='Number of 4-star reviews.'
        )
        public Integer fourStarCount;

        @InvocableVariable(
            label='Three Star Count'
            description='Number of 3-star reviews.'
        )
        public Integer threeStarCount;

        @InvocableVariable(
            label='Two Star Count'
            description='Number of 2-star reviews.'
        )
        public Integer twoStarCount;

        @InvocableVariable(
            label='One Star Count'
            description='Number of 1-star reviews.'
        )
        public Integer oneStarCount;
    }

    @InvocableMethod(
        label='Summarize Reviews'
        description='Retrieves recent reviews for a storefront and provides summary statistics. Requires accountId for security.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.reviews = new List<ReviewSummary>();
        out.success = false;
        out.message = null;
        out.reviewCount = 0;
        out.fiveStarCount = 0;
        out.fourStarCount = 0;
        out.threeStarCount = 0;
        out.twoStarCount = 0;
        out.oneStarCount = 0;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;

        try {
            if (req == null || req.accountId == null) {
                out.message = 'accountId is required.';
                out.reviewsJson = JSON.serialize(out.reviews);
                return new List<Response>{ out };
            }
            if (req.storefrontId == null) {
                out.message = 'storefrontId is required.';
                out.reviewsJson = JSON.serialize(out.reviews);
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
                out.reviewsJson = JSON.serialize(out.reviews);
                return new List<Response>{ out };
            }

            if (storefronts[0].Account__c != req.accountId) {
                out.message = 'Access denied. This storefront does not belong to the specified account.';
                out.reviewsJson = JSON.serialize(out.reviews);
                return new List<Response>{ out };
            }

            Integer daysBack = (req.daysBack != null && req.daysBack > 0) ? req.daysBack : 30;
            Integer reviewLimit = (req.reviewLimit != null && req.reviewLimit > 0) ? Math.min(req.reviewLimit, 100) : 20;
            Date cutoffDate = Date.today().addDays(-daysBack);

            List<Review__c> reviewRecords = [
                SELECT Id, Rating__c, Comments__c, Customer__c, Order_Date__c, Status__c
                FROM Review__c
                WHERE Storefront__c = :req.storefrontId
                AND Order_Date__c >= :cutoffDate
                ORDER BY Order_Date__c DESC
                LIMIT :reviewLimit
            ];

            Decimal totalRating = 0;
            for (Review__c r : reviewRecords) {
                ReviewSummary s = new ReviewSummary();
                s.id = r.Id;
                s.rating = r.Rating__c;
                s.comments = r.Comments__c;
                s.customerId = r.Customer__c;
                s.orderDate = r.Order_Date__c;
                s.status = r.Status__c;
                out.reviews.add(s);

                if (r.Rating__c != null) {
                    totalRating += r.Rating__c;
                    Integer ratingInt = r.Rating__c.intValue();
                    if (ratingInt == 5) out.fiveStarCount++;
                    else if (ratingInt == 4) out.fourStarCount++;
                    else if (ratingInt == 3) out.threeStarCount++;
                    else if (ratingInt == 2) out.twoStarCount++;
                    else if (ratingInt == 1) out.oneStarCount++;
                }
            }

            out.reviewCount = out.reviews.size();
            out.averageRating = out.reviewCount > 0 ? (totalRating / out.reviewCount).setScale(2) : 0;
            out.success = true;
            out.message = out.reviewCount + ' review(s) found from the last ' + daysBack + ' days. Average rating: ' + out.averageRating + ' stars.';
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        out.reviewsJson = JSON.serialize(out.reviews);
        return new List<Response>{ out };
    }
}