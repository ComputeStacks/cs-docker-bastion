<?php

$extendify_partner_logo = 'SET_PARTNER_LOGO';

define('EXTENDIFY_PARTNER_NAME', 'SET_PARTNER_NAME');
define('EXTENDIFY_SHOW_ONBOARDING', get_option('stylesheet', '') === 'extendable');
define('EXTENDIFY_SITE_LICENSE', 'SET_SITE_LICENSE');
define('EXTENDIFY_PARTNER_LOGO', $extendify_partner_logo);
define('EXTENDIFY_ONBOARDING_BG', 'SET_BG_COLOR');
define('EXTENDIFY_ONBOARDING_TXT', 'SET_FG_COLOR');

define('EXTENDIFY_INSIGHTS_URL', 'https://insights.extendify.com');

/** Method to register a site with Extendify */
add_action('admin_init', function () {
    // If not enabled, don't do anything
    if (!defined('EXTENDIFY_INSIGHTS_URL')) {
        return;
    }
    // Only register if not already registered
    if (get_option('extendify_site_id', false)) {
        return;
    }
    // Don't try too often.
    if (get_transient('extendify_registering')) {
        return;
    }
    set_transient('extendify_registering', true, DAY_IN_SECONDS);

    // Attempt to find when the site was created
    // by checking the date on the first post.
    // This is only reliable on new sites.
    $firstPost = get_posts([
        'order' => 'ASC',
        'posts_per_page' => -1,
        'post_status' => ['trash', 'publish', 'any']
    ]);
    if (isset($firstPost[0]->post_date_gmt)) {
        $createdAt = $firstPost[0]->post_date_gmt;
    }


    // Send request for Extendify site id
    try {
        $extendifySite = wp_remote_post(
            trailingslashit(EXTENDIFY_INSIGHTS_URL) . 'api/v1/register',
            [
                'headers' => [
                    'Content-Type' => 'application/json',
                    'X-Extendify' => true,
                ],
                'body' => wp_json_encode([
                    'launch' => defined('EXTENDIFY_SHOW_ONBOARDING')
                        ? EXTENDIFY_SHOW_ONBOARDING
                        : false,
                    'siteCreatedAt' => $createdAt,
                ]),
            ]
        );
        $extendifySite = wp_remote_retrieve_body($extendifySite);
        $extendifySite = json_decode($extendifySite, true);
        if (isset($extendifySite['siteId'])) {
            update_option('extendify_site_id', $extendifySite['siteId']);
            if (class_exists('ExtendifyInsights')) {
                (new ExtendifyInsights)->run();
            }
        }
    } catch (Exception $e) {
        // Do nothing
    }
});

/** Insights */
if (!wp_next_scheduled('extendify_insights')) {
    if (get_option('extendify_insights_stop', false)) {
        return;
    }
    wp_schedule_event(time(), 'daily', 'extendify_insights');
}
add_action('extendify_insights', [new ExtendifyInsights, 'run']);

class ExtendifyInsights
{
    public $domain;
    public function __construct()
    {
        $this->domain = defined('EXTENDIFY_INSIGHTS_URL')
            ? trailingslashit(EXTENDIFY_INSIGHTS_URL)
            : null;
    }
    public function run()
    {
        if (!$this->domain) {
            return;
        }
        if (!$siteId = get_option('extendify_site_id', false)) {
            return;
        }

        $res = wp_remote_post($this->domain . 'api/v1/insights', [
            'headers' => [
                'Content-Type' => 'application/json',
                'X-Extendify-Site-Id' => $siteId,
            ],
            'body' => wp_json_encode([
                'site' => $this->getSiteData(),
                'pages' => $this->getPageData(),
                'plugins' => get_option('active_plugins'),
            ]),
        ]);
        $response = json_decode(wp_remote_retrieve_body($res));
        if (isset($response->stop)) {
            update_option('extendify_insights_stop', true);
            wp_clear_scheduled_hook('extendify_insights');
        }
    }
    private function getSiteData()
    {
        $partner = defined('EXTENDIFY_PARTNER_NAME')
            ? EXTENDIFY_PARTNER_NAME
            : null;
        if (!$partner && isset($GLOBALS['extendify_sdk_partner'])) {
            $partner = $GLOBALS['extendify_sdk_partner'];
        };
        $devBuild = defined('EXTENDIFY_PATH')
            ? is_readable(EXTENDIFY_PATH . 'public/build/.devbuild')
            : null;
        $siteType = get_option('extendify_siteType', '');
        $siteType = isset($siteType['slug']) ? $siteType['slug'] : '';

        return [
            'title' => get_bloginfo('name'),
            'url' => get_bloginfo('url'),
            'wpVersion' => get_bloginfo('version'),
            'language' => get_bloginfo('language'),
            'siteType' => $siteType,
            'theme' => get_option('stylesheet', ''),
            'partner' => $partner,
            'isDev' => $devBuild,
        ];
    }
    private function getPageData()
    {
        $pages = get_posts([
            'posts_per_page' => -1,
            'post_status' => ['trash', 'publish', 'any'],
            'post_type' => 'page'
        ]);
        $pageData = array_map(function ($page) {
            $revisions = wp_get_post_revisions($page->ID, ['posts_per_page' => -1]);
            return [
                'ID' => $page->ID,
                'usedLaunch' => filter_var(get_post_meta($page->ID, 'made_with_extendify_launch', true), FILTER_VALIDATE_BOOLEAN),
                'name' => $page->post_name,
                'title' => $page->post_title,
                'status' => $page->post_status,
                'date' => $page->post_date_gmt,
                'template' => get_page_template_slug($page->ID),
                'revisions' => array_map(function ($pageRevision) {
                    return [
                        'ID' => $pageRevision->ID,
                        'name' => $pageRevision->post_name,
                        'status' => $pageRevision->post_status,
                        'title' => $pageRevision->post_title,
                        'date' => $pageRevision->post_date_gmt,
                    ];
                }, $revisions)
            ];
            return $page;
        }, $pages);
        // Check whether the page data matches our last check
        // if it does, we can just not send the same data over
        $pageDataLastTime = get_option('extendify_page_data_last_time', []);
        if ($pageData === $pageDataLastTime) {
            return;
        }
        update_option('extendify_page_data_last_time', $pageData);
        return $pageData;
    }
}