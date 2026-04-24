import 'package:flutter/material.dart';

class UserAgreementScreen extends StatelessWidget {
  const UserAgreementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'User Agreement',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: const Text(
          '''SHEMET Terms and Conditions
This is  Zweiklang PTE. LTD., the company's product "SHEMET" and its subsequent versions ("SHEMET", "we" or "our") are incorporated into and bound to these Terms of Service. In these Terms of Service, we shall refer to our products and services as the "Service", unless stated otherwise. Please read on to learn more about our data processing practices. Your use of the Service means that you agree to all the terms stipulated within these Terms of Service. If you do not agree to any of the terms in these Terms of Service, please do not use the Service.
 

Before using SHEMET, you must carefully read and fully understand all the terms stipulated within these Terms of Service, as well as the national laws and regulations on such Internet information services. If you object to any of the terms of these Terms of Service, you may choose not to use Shemet as using it means that you agree to abide by all the provisions of these Terms of Service, and any subsequent amendments we may make to these Terms of Service from time to time. Additionally, you must be at least 18 years old and have full capacity to enter contracts under the laws of the jurisdiction in which you reside. SHEMET shall not be held responsible for any events or incidents that occur outside of the platform between its users. If you do not meet the above conditions, you should immediately discontinue the use of the Service.

 

1. Information we collect

 

When you install the Service on your device and register with Shemet, your personal identity information may be collected during the download process of the Service (based on the requirements during the download process) ("Information"). To register with Shemet, you need to provide your nickname, gender, birthday, location and mobile number, depending on the device used for the Service. When you log in with a third-party account, we may collect other information you provide to us (see "Your user profile").

Shemet may also collect non-personally identifiable information, such as certain personal details, including your country of residence and preferences. In addition, Shemet may collect and store information about how you and others use the Service and our website, as well as how you interact with it. This may include SMS data, region, specific data, device usage and connection information, IP address, device functionality, bandwidth, page browsing statistics, network type and the number of interactions with our application.

 
Shemet allows you to share communications containing information in the form of text messages, photos, screenshots, videos and other types of media, which may contain your data or information ("Communications"), within Shemet applications with other users. You can choose to send and share these Communications within SHEMET. When you decide to share such Communications, you agree that these Communications will be stored on our servers. If you choose to share these Communications with other Shemet users, it may not be possible to remove them from our servers or make them unavailable to those with whom you have shared them. By choosing to share these Communications, you should be aware that you may lose control over how these Communications are used. It is possible that these Communications may become publicly available, depending on your behavior or the actions of others who share the information with you. We are not responsible for any use or misuse of these Communications you choose to share.

When using SHEMET, you agree that we may collect, use, or disclose (as applicable) user content, such as photos, screenshots, comments, and other materials, that you create on SHEMET. You also agree that by using SHEMET, your photos may be captured by other users on SHEMET. If other users use the capture function provided by SHEMET, these photos may be stored and used within SHEMET and third-party services, such as Facebook, etc.. You can not change the third-party sharing options on the SHEMET settings. If you do not agree to any of the terms of these Terms of Service, please refrain from using the Service.

 

In the event of a SHEMET crash, freeze, contains bug or any errors, we will collect error report information to investigate the issues and enhance the stability of SHEMET for future releases. Typically, these reports do not contain any personally identifiable information, only incidental information. These error reports will include information about your device type and version, device identifier, when the error occurred, the features in use, and the status of SHEMET at the time of error occurred. We will not use this information for any purpose beyond investigating and rectifying errors. Unless otherwise specified in these Terms of Service, we will not rent or sell your information to any third party without your consent.

 
How We Use or Disclose the Information Collected

 

We will use or, where applicable, disclose your Information for the following purpose:

• Verifying your identity;

• Establishing contact with you after SHEMET is enabled;

• Allowing you to use certain functions of SHEMET as provided from time to time;

• Displaying the name of the person you communicate with and displaying your name to the person you communicate with in SHEMET;

• Sending you administrative notifications, alerts and communications related to your use of SHEMET;

• Providing you with relevant content by using the information you allow us to collect or the information you provide to social media providers associated with your SHEMET account (for example, information about the respective locations of you and your SHEMET contacts);

• Operations for internal use, including troubleshooting, data analysis, testing, research, service improvement, error detection and prevention, and addressing fraud or other illegal activities;

• Complying with legal obligations to use or disclose such information as required by law, any legal process, any law enforcement agency, or in the interest of national or public security;

• Protecting and defending our rights or property, including the enforcement of our Terms of Service and agreements, or dealing with companies involved with SHEMET, such as the purchases or sales of business units, asset acquisitions, mergers, sales or other similar events;

• Sharing your Information with other companies in the SHEMET Group which will be subject to the same terms as specified in these Terms of Service.

• Sharing your Information with third-party organizations ("Service Providers") that assist us in providing the Service to you. Under reasonable confidentiality terms, these Service Providers will be granted access to your Information, as necessary for the provision of the Service. For example, SHEMET will share your phone number or email with third-party SMS and email providers to send you authenticated SMS or email when you register with SHEMET. We require these third parties to use your Information only for sending you SMS or e-mail in accordance with the contract, and to employ appropriate security measures to safeguard your Information. Furthermore, certain SHEMET servers are owned and hosted by third-party Service Providers.

• We may share aggregate or anonymous versions of the Information with third parties, including advertisers and investors. For example, we can provide advertisers with information regarding the number of users on SHEMET. This information does not contain any personally identifiable information and is used to develop content and services aligned with your interests.

• For the purposes of sharing anonymous data of our Service with third parties, we may eliminate certain data within the Information obtained, specifically data that can identify you. We may also merge your Information with other information in a manner that no longer links it to you and share this summary.

If we intend to use or disclose your Information in any other manner, we will conduct an assessment to determine whether such use or disclosure will have any adverse effects on you and implement measures to minimise any potential adverse consequences. We will notify you about our intention to use or disclose such Information before it is used or disclosed, and you will have an opportunity to reject our proposed use of such Information.

 User’s own disclosure of information (Including Personally Identifiable Information) or Content

SHEMET allows you to choose whether you wish to share your information or content. Where you choose to do so:

• Any information or content that you voluntarily disclose by publishing it on SHEMET, such as user content, becomes accessible to the public and shall be deemed to be public information. If you choose to share your user information or content, other users may re-share your information or content without your knowledge. We shall not be responsible in any whatsoever for such sharing.

• You may choose to un-share or delete your information or content at any time. However, if information or content created on SHEMET (such as screenshots, etc.) is deleted, copies may still be visible in the cache and archive pages of the Service, or if other users or third parties have copied or saved the information. (for example, Facebook, etc.)

How to use the services and SHEMET

Your access to and use of the Services is subject to these terms and all applicable laws and regulations. You agree that you will comply with these terms of Services and SHEMET's Community Guidelines and will not:

• Create, upload, transmit, distribute, or store any content that is inaccurate, unlawful, infringing, defamatory, obscene, pornographic, invasive of privacy or publicity rights, harassing, threatening, abusive, inflammatory, or otherwise objectionable;

• Impersonate any person or entity, falsely claim an affiliation with any person or entity, or access SHEMET accounts of others without permission, forge another person’s identity, or content of information transmitted via the Services, or perform any other similar fraudulent activity;

• Defame, harass, abuse, threaten or defraud users of SHEMET, or collect, or attempt to collect, personal information about users or third parties without their consent;

• Remove, circumvent, disable, damage or otherwise interfere with security-related features of the Services or User Content, features that prevent or restrict use or copying of any content accessible through the Services, features that enforce limitations on the use of the Services or User Content, or delete the copyright or other proprietary rights notices on the Services or User Content;

• Reverse engineer, decompile, disassemble or otherwise attempt to discover the source code of the Services or any part thereof, except and only to the extent that this activity is expressly permitted by the law of your jurisdiction of residence;

• Modify, adapt, translate or create derivative works based upon the Services or any part thereof, except and only to the extent that such activity is expressly permitted by applicable law notwithstanding this limitation;

• Interfere with or damage operation of the Services or any user’s enjoyment of them, by any means, including uploading or otherwise disseminating viruses, adware, spyware, worms, or other malicious code;

• Manipulate identifiers in order to disguise the origin of any User Content transmitted through the Twitch Services;

• Interfere with or disrupt the Services or servers or networks connected to the Services, or disobey any requirements, procedures, policies or regulations of networks connected to the Services; use the Services in any manner that could interfere with, disrupt, negatively affect or inhibit other users from fully enjoying the Services, or that could damage, disable, overburden or impair the functioning of the Services in any manner;

• Attempt to circumvent any content filtering techniques we employ, or attempt to access any service or area of the Services that you are not authorized to access;

• Use the Services for any illegal purpose, or in violation of any local, state, national, or international law or regulation, including, without limitation, laws governing intellectual property and other proprietary rights, data protection and privacy.



SHEMET takes no responsibility and assumes no liability for any User Content or for any loss or damage resulting therefrom, nor is SHEMET liable for any mistakes, defamation, slander, libel, omissions, falsehoods, obscenity, pornography or profanity you may encounter when using the Services. Your use of the Services is at your own risk. In addition, these rules do not create any private right of action on the part of any third party or any reasonable expectation that the Services will not contain any content that is prohibited by such rules.

SHEMET is not liable for any statements or representations included in User Content. SHEMET does not endorse any User Content, opinion, recommendation, or advice expressed therein, and SHEMET expressly disclaims any and all liability in connection with User Content. To the fullest extent permitted by applicable law, SHEMET reserves the right to remove, screen or edit any User Content posted or stored on the Services at any time and without notice, including where such User Content violates these terms of Use of the Services or applicable law, and you are solely responsible for creating backup copies of and replacing any User Content you post or store on the Services at your sole cost and expense. Any use of the Services in violation of the foregoing violates these terms of Use of the Services and may result in, among other things, termination or suspension of your rights to use the Services.



5. Cash Rebate and Withdrawal Policy



Our platform strictly prohibits any form of cash rebates. Users may only withdraw points earned through receiving gifts, tips from others, or participation in platform activities. Any attempt to use the withdrawal feature for illegal purposes, such as money laundering, fraud, gambling, or other unlawful activities, is strictly prohibited. In the event of any violation of these terms, the platform will immediately suspend the offending account's access privileges and report the case to the relevant regulatory authorities in accordance with the law.



6. SHEMET prohibits users from creating, uploading, or distributing content that facilitates the exploitation or abuse of children,such as:

 

• Inappropriate interaction targeted at a child (for example, groping or caressing).

• Child grooming (for example, befriending a child online to facilitate, either online or offline, sexual contact and/or exchanging sexual imagery with that child).

• Sexualization of a minor (for example, imagery that depicts, encourages or promotes the sexual abuse of children or the portrayal of children in a manner that could result in the sexual exploitation of children).

• Sextortion (for example, threatening or blackmailing a child by using real or alleged access to a child’s intimate images).

• Trafficking of a child (for example, advertising or solicitation of a child for commercial sexual exploitation).

If child sexual abuse content is identified in user posts, we will take immediate action against the user who posted such content. Actions may include, but are not limited to: removing the offending content, restricting the user's ability to post content, suspending the user's account, and reporting to the appropriate authorities. You can also report content related to Child Sexual Abuse and Exploitation (CSAE) behaviour on the platform by using the "HELP" feature in SHEMET.

 

7. Your user profile

 

The information you enter into your user profile may be shared with your SHEMET contacts. You can control the profile settings and access and modify it at any time using the SHEMET application. In addition, if you use your Facebook account（Account types include but are not limited to: Google, Apple ID. Your personal data can be used by other SHEMET users connected to you on SHEMET. In addition, unless you choose to log out which you can do at any time within the (SHEMET application), other SHEMET users can see your personal data, such as your distance from other users in the contact list. You also have the option to "block" any SHEMET user in your contact list. If so, that blocked user will not be able to view your personal information. In addition, if you or your friends have signed into the service using Facebook, SHEMET may pre-fill your profile with certain information, such as your name and Facebook profile image.

 

8. Data access and deletion



You have complete control over the information you choose to share with us through the use of SHEMET. You can manage this by changing the settings in SHEMET or mobile device. Alternatively, you can uninstall SHEMET from your mobile device entirely. You can request that we cease using or delete all your data at any time. However, this action requires the deletion of your SHEMET account and you would not be able to continue using the Service. If you ask us to delete your account, we will make commercially reasonable efforts to delete your data from our servers. However, we may not be able to delete any previously sent text messages, photos, videos or other forms of personal identity information that you have shared with other users in the SHEMET application or through the SHEMET application, or on blogs, bulletin boards or chat rooms on our website or elsewhere. In such cases your personal data and any information which you have shared in public may be viewed and used by others. We are not responsible for any use or misuse of information resulting from your disclosure.

If you believe that any data provided to us or collected by us is inaccurate and cannot be corrected through the settings, you may request data correction by sending a request to officalshemet@gmail.com.

 

9. Outbound link

 

If you visit a website, product or service provided by a third party (including through a service or SHEMET’s website), that third party may also collect information about you. Please refer to the privacy policy of the respective third party for more information on how they use the information they collect. These Terms of Service do not apply to any information exchange between you and any third party.

 
10. Safety
 
Protecting user privacy and personal information is our top priority. We will do our best to ensure the privacy of all Information provided to us, or collected by us. By providing us with the Information or using the Service, you agree that all Zweiklang PTE. LTD. and SHEMET employees, contractors, agents and third-party Service Providers are granted access to this Information in order to provide, operate, develop, maintain, support or improve Service, where necessary. SHEMET uses password protection, access logs and system monitoring to protect the confidentiality and security of all member information.
However, due to the inherent nature of the Internet and related technologies, we cannot guarantee the protection of the Information from loss, abuse or change within our control.
Your Information may be stored and processed in any country where Zweiklang PTE. LTD. is located. In this regard, or for the purpose of sharing or disclosing the data described in these Terms of Service, Zweiklang PTE. LTD. and SHEMET reserve the right to transfer information outside your country. By using the Service, you agree to the transfer of such information outside your country.
 
11. Age
 
The Service is not applicable to any children under the age of 18. As part of the Service, we do not intentionally collect any personally identifiable information of children under the age of 18. If we become aware that we have inadvertently received personally identifiable information from users under the age of 18 as part of the Service, we will promptly remove that information from our records. If our approach changes in the future, we will obtain prior verifiable consent from the parents before obtaining any personally identifiable information from children under the age of 18.
 
12. Account information
 
You can acquire "DIamonds" through recharging (please consider this carefully as it is non-refundable, specific details can be found in the Recharge Agreement) or earn "points" through activities like live-streaming. In order to maintain user activity, if you do not log in to SHEMET for three consecutive months, the "diamonds" or "points" will be cleared.
 
13. Amendments
 
We reserve the right to amend these Terms of Service at our own discretion and update it on SHEMET at any time without prior notice to you. Once the updated Terms of Service are published, they will replace the original Terms of Service without further notice to you. You can check the latest version of the Terms of Service on SHEMET. Additionally, SHEMET will inform users that the Terms of Service have been changed. In order for you to continue using SHEMET, you must click "accept" on the new terms. If you do not accept the modified terms after SHEMET modifies these Terms of Service, you will not be able to use SHEMET services.
 
14. Dispute Resolution
 
Any dispute, controversies or differences arising out of or related to these Terms of Service, including any questions regarding its existence, validity or termination, shall first be referred to mediation in Germany, in accordance with the Germany International Mediation Rules for the time being in force. If you have any questions or complaints about the use of these Terms of Service, please contact our data protection officer via email at officalshemet@gmail.com. In the event that the dispute cannot be settled in mediation, you agree that the dispute shall be governed by the laws of Germany and shall be subject to arbitration in Germany administered by the Germany International Arbitration Centre in accordance with the Germany International Arbitration Rules.
If any provision of these Terms of Service is invalid or unenforceable in whole or in part for any reason, other provisions of these Terms of Service shall remain valid and binding. SHEMET and users shall try their best to embody the original intention of these Terms of Service.
 
15. Contact information
 
If you have any questions about any terms or parts of these Terms of Service, please send your inquiries via email to officalshemet@gmail.com. Any personally identifiable information used for inquiries and responses shall be handled in accordance with these Terms of Service.''',
          style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
        ),
      ),
    );
  }
}
