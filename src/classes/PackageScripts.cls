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
 * @author Ulas Kutuk
 **/
global without sharing class PackageScripts implements InstallHandler, UninstallHandler {

    /**
     * Required for UninstallHandler interface implementation
     * ID organizationId();
     * ID uninstallerId();
     * @param  {InstallContext} context Object providing methods to retrieve
     *                                  organization Id and uninstalling user Id.
     */
    global void onInstall(InstallContext context) {
        PackageScripts.install();

        String[] toAddresses = new String[]{'package@fonteva.com'};
        try {
            Messaging.SingleEmailMessage mail =
                    new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddresses);
            mail.setReplyTo('noreply@fonteva.com');
            mail.setSenderDisplayName('FONTEVA ' + PackageUtils.namespace.toUppercase());
            String mailSubject = PackageUtils.namespace.toUppercase() + ' ';
            mailSubject += 'INSTALLED';
            mail.setSubject(mailSubject);
            mail.setPlainTextBody('Successfully Installed');
            Messaging.sendEmail(new Messaging.Email[] { mail });
        }
        catch (Exception ex) {
            Framework__System_Log__c log = new Framework__System_Log__c();
            log.Framework__Exception_Data__c = 'Exception Type: ' + ex.getTypeName() + '\nCaused By: ' + ex.getCause();
            log.Framework__Data__c = 'EXCEPTION: ' + ex.getMessage();
            insert log;
        }
    }

    /**
     * Required for UninstallHandler interface implementation
     * ID organizationId();
     * ID uninstallerId();
     * @param  {UninstallContext} context Object providing methods to retrieve
     *                                    organization Id and uninstalling user Id.
     */
    global void onUninstall(UninstallContext context) {
        User u = [Select Id, Username, FirstName, LastName, Title,
                CompanyName, Phone, Email, Street, City, State,
                PostalCode, Country from User where Id =: context.uninstallerId()];

        String eventDescriptor = 'Uninstall';
        String jsonData = '[{' +
                '"organization_id": "' + context.organizationId() + '",' +
                '"user_id": "' + context.uninstallerId() + '",' +
                '"username": "' + u.Username + '",' +
                '"first_name": "' + u.Phone + '",' +
                '"last_name": "' + u.LastName + '",' +
                '"phone": "' + u.Phone + '",' +
                '"email": "' + u.Email + '",' +
                '"company": "' + u.CompanyName +'",' +
                '"title": "' + u.Title + '",' +
                '"package": "' + PackageUtils.namespace + '",' +
                '"event": "' + eventDescriptor + '"' +
                '}]';

        String[] toAddresses = new String[]{'package@fonteva.com'};
        Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();
        mail.setToAddresses(toAddresses);
        mail.setReplyTo('noreply@fonteva.com');
        mail.setSenderDisplayName('FONTEVA ' + PackageUtils.namespace.toUppercase());
        mail.setSubject(PackageUtils.namespace.toUppercase() + ' UNINSTALLED');
        mail.setPlainTextBody(jsonData);
        Messaging.sendEmail(new Messaging.Email[] { mail });
    }

    /**
     * Execute the installation scripts for the OrderApi managed package
     */
    global static void install() {
        new Install().run();
    }

    /**
     * Runs all default installation scripts for the MANAGED PACKAGE
     *
     * @implements Framework.Scriptable
     * @author Ulas Kutuk
     * @since 1.0
     */
    global class Install implements Framework.Scriptable {
        global void run() {
            Framework.Log.push(PackageScripts.Install.class.getName(),'run');
            try {
                new Register().run();
                new CustomScripts().run();
                new Rollups().run();

                registerAppUpdates();
            }
            catch (Exception ex) {
                Framework.Log.debugException(ex);
            }
            Framework.Log.pop();
        }
    }

    global class Register implements Framework.Scriptable {
        global void run() {

            // R E G I S T E R I N G     T H E     A P P
            Framework.RegisteredApp toc = new Framework.RegisteredApp();
            toc.namespace = PackageUtils.namespace;
            toc.name = 'TOC';
            toc.description = 'Managed Package Developed by TOC';
            toc.isManaged = true;
            toc.isEnabled = true;
            toc.installClass = PackageScripts.Install.class.getName();
            Framework.Config.push(toc);


            // R E G I S T E R I N G    T H E     O B J E C T S
            Framework.RegisteredObject[] regObjects = new List<Framework.RegisteredObject>();

            // R O U T I N G    R U L E S
            Framework.RoutingRule[] rules = new List<Framework.RoutingRule>();

            // Sales Order ** Routing Rule Extension **
            // ---------------------------------------------------------------------
            Framework.RoutingRule aRule = new Framework.RoutingRule();
            aRule.apexClass = TOC_SalesOrders.class.getName();
            aRule.namespace = PackageUtils.namespace;
            aRule.isEnabled = true;
            aRule.sObjectName = SObjectType.OrderApi__Sales_Order__c.getName();
            aRule.executionOrder = 0;
            rules.add(aRule);

            Framework.Config.push(rules);
        }
    }

    global class Rollups implements Framework.Scriptable {
        global void run() {
            Framework.Log.push(PackageScripts.class.getName(),'.createRollups');

            Framework.RollupSummaryField[] rsfs = new List<Framework.RollupSummaryField>();

            /**
             * Contact.Order_Total (Count)
             */
            Framework.RollupSummaryField rsf = new Framework.RollupSummaryField();
            rsf.namespace = PackageUtils.namespace;
            rsf.childField = SObjectType.OrderApi__Sales_Order__c.fields.OrderApi__Total__c.getName();
            rsf.childSObject = SObjectType.OrderApi__Sales_Order__c.getName();
            rsf.filter = SObjectType.OrderApi__Sales_Order__c.fields.OrderApi__Payment_Method__c.getName() + ' != null';
            rsf.operation = Framework.RollupSummaryField.Operation.Sum.name();
            rsf.parentField = Framework.SchemaService.getDescribe(Contact.Order_Total__c).getName();
            rsf.parentSObject = Framework.SchemaService.getDescribe(Contact.SObjectType).getName();
            rsf.relationshipField = Framework.SchemaService.getDescribe(OrderApi__Sales_Order__c.OrderApi__Contact__c).getName();
            rsf.isEnabled = true;
            rsfs.add(rsf);

            Framework.Config.push(rsfs);

            Framework.Log.pop();
        }
    }

    global class CustomScripts implements Framework.Scriptable {
        global void run() {
            Framework.Log.push(PackageScripts.CustomScripts.class.getName(),'run');

            Framework.CustomScript[] customScripts = new List<Framework.CustomScript>();


            // Register App, Objects, and Routing Rules
            Framework.CustomScript cs2 = new Framework.CustomScript();
            cs2.apexClass = PackageScripts.Register.class.getName();
            cs2.namespace = PackageUtils.namespace;
            cs2.name = 'Register App, Custom Objects, and Routing Rules';
            cs2.description = 'Creates the configurations required for the Fonteva ' +
                    'Order Management app to operate with the Fonteva Framework.';
            customScripts.add(cs2);


            // Create Rollup Summary Fields
            Framework.CustomScript cs4 = new Framework.CustomScript();
            cs4.apexClass = PackageScripts.Rollups.class.getName();
            cs4.namespace = PackageUtils.namespace;
            cs4.name = 'Create Rollup Summary Fields';
            cs4.description = 'Creates the required rollup summary field configurations for the ' +
                    'Fonteva Order Management app.';
            customScripts.add(cs4);

            // Run Install Scripts
            Framework.CustomScript cs5 = new Framework.CustomScript();
            cs5.apexClass = PackageScripts.Install.class.getName();
            cs5.namespace = PackageUtils.namespace;
            cs5.name = 'Run Install Scripts';
            cs5.description = 'Runs all installation scripts for Fonteva Order Management.';
            customScripts.add(cs5);


            Framework.Config.push(customScripts);

            Framework.Log.pop();
        }
    }

    static void registerAppUpdates() {
        Framework.AppUpdate[] results = new List<Framework.AppUpdate>();

        Framework.AppUpdate appUpdateObj = Framework.AppUpdate.get('CONTACT UPDATE');

        if (appUpdateObj == null) {
            appUpdateObj = new Framework.AppUpdate();
            appUpdateObj.configId = 'CONTACT UPDATE';
            appUpdateObj.displayName = 'Enables Contact Phone field update';
            appUpdateObj.description = 'The ability to update teh phone field on the contact.';
            appUpdateObj.isActivated = false;
            appUpdateObj.namespace = PackageUtils.namespace;
            results.add(appUpdateObj);
        }
        else if (String.isEmpty(appUpdateObj.namespace)) {
            appUpdateObj.description = 'Enables Contact Phone field update.';
            appUpdateObj.namespace = PackageUtils.namespace;
            results.add(appUpdateObj);
        }

        if (!results.isEmpty()) {
            Framework.Config.push(results);
        }


        //How to disable critical updates
//        Framework.AppUpdate app = Framework.AppUpdate.get('CONTACT UPDATE');
//        app.isActivated = false;
//        Framework.Config.push(app);


    }


}
