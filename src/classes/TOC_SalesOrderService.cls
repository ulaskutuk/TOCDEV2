/*
 * -----------------------------------------------------------------------------
 * COPYRIGHT (C) 2018, FONTEVA, INC.
 * ALL RIGHTS RESERVED.
 *
 * ALL INFORMATION CONTAINED HEREIN IS, AND REMAINS THE PROPERTY OF FONTEVA
 * INCORPORATED AND ITS SUPPLIERS, IF ANY. THE INTELLECTUAL AND TECHNICAL
 * CONCEPTS CONTAINED HEREIN ARE PROPRIETARY TO FONTEVA INCORPORATED AND
 * ITS SUPPLIERS AND MAY BE COVERED BY U.S. AND FOREIGN PATENTS, PATENTS IN
 * PROCESS, AND ARE PROTECTED BY TRADE SECRET OR COPYRIGHT LAW. DISSEMINATION
 * OF THIS INFORMATION OR REPRODUCTION OF THIS MATERIAL IS STRICTLY FORBIDDEN
 * UNLESS PRIOR WRITTEN PERMISSION IS OBTAINED FROM FONTEVA, INC.
 * -----------------------------------------------------------------------------
 */

/**
 * Service class for the OrderApi__Sales_Order__c SObjectType
 * @author Ulas Kutuk
 **/
public class TOC_SalesOrderService {

    public static void setDefaults(OrderApi__Sales_Order__c[] records) {
        Framework.Log.push(TOC_SalesOrderService.class.getName(),'setDefaults');

        for (OrderApi__Sales_Order__c so : records) {
            if (so.OrderApi__Payment_Method__c != null) {
                so.OrderApi__Customer_Reference_Number__c = 'Has Payment Method';
            }
        }

        Framework.Log.pop();
    }

    /**
     * What is this method doing ?
     * @event afterUpdate
     * @update OrderApi__Sales_Order__c
     */
    public static void updatePaymentMethod(Map<Id,OrderApi__Sales_Order__c> oldMap, OrderApi__Sales_Order__c[] records) {
        Framework.Log.push(TOC_SalesOrderService.class.getName(),'updatePaymentMethod');

        Set <Id> contactIds = new Set<Id>();

        for (OrderApi__Sales_Order__c so : records) {
            if (so.OrderApi__Payment_Method__c != null && so.OrderApi__Contact__c != null) {
                contactIds.add(so.OrderApi__Contact__c);
            }
        }

        if (!contactIds.isEmpty()) {
            Contact[] contacts = (Contact[]) new Framework.Selector(Contact.SObjectType).selectById(contactIds);

            for (Contact c : contacts) {
                c.Description = 'This Contact used a verified Payment Method';

                if(Framework.AppUpdate.isActivated('CONTACT UPDATE')) {
                    c.Phone = '12345';
                }
            }
            update contacts;
        }
        Framework.Log.pop();
    }
}