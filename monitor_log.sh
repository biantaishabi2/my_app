Apr 06 15:16:02 co mix[2408038]: 当前页面表单项数量: 15
Apr 06 15:16:02 co mix[2408038]: ===== 调试信息结束 =====
Apr 06 15:16:02 co mix[2408038]: [info] Sent 200 in 26ms
Apr 06 15:16:35 co mix[2408038]: [info] CONNECTED TO Phoenix.LiveView.Socket in 71µs
Apr 06 15:16:35 co mix[2408038]:   Transport: :longpoll
Apr 06 15:16:35 co mix[2408038]:   Serializer: Phoenix.Socket.V2.JSONSerializer
Apr 06 15:16:35 co mix[2408038]:   Parameters: %{"_csrf_token" => "Jw8bAic8Kk0fZRU8FxY4In1sSDJ9cxQuTnVfFjE8R1OvQOap6Ypw17Nh", "_live_referer" => "undefined", "_mount_attempts" => "0", "_mounts" => "0", "_track_static" => %{"0" => "http://phoenix.biantaishabi.org/assets/app.css?v=1743952562", "1" => "http://phoenix.biantaishabi.org/assets/app.js?v=1743952562"}, "vsn" => "2.0.0"}
Apr 06 15:16:35 co mix[2408038]: [debug] MOUNT MyAppWeb.FormLive.Submit
Apr 06 15:16:35 co mix[2408038]:   Parameters: %{"id" => "b8fd73c1-c966-43e6-935f-06a893313ebd"}
Apr 06 15:16:35 co mix[2408038]:   Session: %{"_csrf_token" => "saMdaVouMTZJFYYRK58ELDZF", "live_socket_id" => "users_sessions:tx83Gs_ld1JRNqfGogyr_uB9keh-BXaCRzb-yKBYlBE=", "user_token" => <<183, 31, 55, 26, 207, 229, 119, 82, 81, 54, 167, 198, 162, 12, 171, 254, 224, 125, 145, 232, 126, 5, 118, 130, 71, 54, 254, 200, 160, 88, 148, 17>>}
Apr 06 15:16:35 co mix[2408038]: [debug] QUERY OK source="users_tokens" db=0.9ms idle=1189.6ms
Apr 06 15:16:35 co mix[2408038]: SELECT u1."id", u1."email", u1."hashed_password", u1."confirmed_at", u1."inserted_at", u1."updated_at" FROM "users_tokens" AS u0 INNER JOIN "users" AS u1 ON u1."id" = u0."user_id" WHERE ((u0."token" = $1) AND (u0."context" = $2)) AND (u0."inserted_at" > $3::timestamp + (-(60)::numeric * interval '1 day')) [<<183, 31, 55, 26, 207, 229, 119, 82, 81, 54, 167, 198, 162, 12, 171, 254, 224, 125, 145, 232, 126, 5, 118, 130, 71, 54, 254, 200, 160, 88, 148, 17>>, "session", ~U[2025-04-06 15:16:35.494794Z]]
Apr 06 15:16:35 co mix[2408038]: ↳ Phoenix.LiveView.Utils.assign_new/3, at: lib/phoenix_live_view/utils.ex:79
Apr 06 15:16:35 co mix[2408038]: [debug] QUERY OK source="forms" db=1.2ms idle=1191.1ms
Apr 06 15:16:35 co mix[2408038]: SELECT f0."id", f0."title", f0."description", f0."status", f0."user_id", f0."default_page_id", f0."inserted_at", f0."updated_at" FROM "forms" AS f0 WHERE (f0."id" = $1) ["b8fd73c1-c966-43e6-935f-06a893313ebd"]
Apr 06 15:16:35 co mix[2408038]: ↳ MyApp.Forms.get_form/1, at: lib/my_app/forms.ex:50
Apr 06 15:16:35 co mix[2408038]: [debug] QUERY OK source="form_pages" db=0.6ms idle=1192.8ms
Apr 06 15:16:35 co mix[2408038]: SELECT f0."id", f0."title", f0."description", f0."order", f0."form_id", f0."inserted_at", f0."updated_at", f0."id" FROM "form_pages" AS f0 WHERE (f0."id" = $1) ["6b67f044-ae73-4e70-9908-0c1d20b82e7b"]
Apr 06 15:16:35 co mix[2408038]: ↳ MyAppWeb.FormLive.Submit.get_published_form/1, at: lib/my_app_web/live/form_live/submit.ex:17
Apr 06 15:16:35 co mix[2408038]: [debug] QUERY OK source="form_pages" db=0.8ms idle=1192.8ms
Apr 06 15:16:35 co mix[2408038]: SELECT f0."id", f0."title", f0."description", f0."order", f0."form_id", f0."inserted_at", f0."updated_at", f0."form_id" FROM "form_pages" AS f0 WHERE (f0."form_id" = $1) ORDER BY f0."form_id", f0."order" ["b8fd73c1-c966-43e6-935f-06a893313ebd"]
Apr 06 15:16:35 co mix[2408038]: ↳ MyAppWeb.FormLive.Submit.get_published_form/1, at: lib/my_app_web/live/form_live/submit.ex:17
Apr 06 15:16:35 co mix[2408038]: [debug] QUERY OK source="form_items" db=1.5ms idle=1192.8ms
Apr 06 15:16:35 co mix[2408038]: SELECT f0."id", f0."label", f0."description", f0."placeholder", f0."type", f0."max_rating", f0."min", f0."max", f0."step", f0."show_format_hint", f0."format_display", f0."min_date", f0."max_date", f0."date_format", f0."min_time", f0."max_time", f0."time_format", f0."region_level", f0."default_province", f0."matrix_rows", f0."matrix_columns", f0."matrix_type", f0."selection_type", f0."image_caption_position", f0."allowed_extensions", f0."max_file_size", f0."multiple_files", f0."max_files", f0."category", f0."visibility_condition", f0."required_condition", f0."order", f0."required", f0."validation_rules", f0."form_id", f0."page_id", f0."inserted_at", f0."updated_at", f0."form_id" FROM "form_items" AS f0 WHERE (f0."form_id" = $1) ORDER BY f0."form_id", f0."order" ["b8fd73c1-c966-43e6-935f-06a893313ebd"]
Apr 06 15:16:35 co mix[2408038]: ↳ MyAppWeb.FormLive.Submit.get_published_form/1, at: lib/my_app_web/live/form_live/submit.ex:17
Apr 06 15:16:35 co mix[2408038]: [debug] QUERY OK source="form_items" db=1.6ms idle=1195.2ms
Apr 06 15:16:35 co mix[2408038]: SELECT f0."id", f0."label", f0."description", f0."placeholder", f0."type", f0."max_rating", f0."min", f0."max", f0."step", f0."show_format_hint", f0."format_display", f0."min_date", f0."max_date", f0."date_format", f0."min_time", f0."max_time", f0."time_format", f0."region_level", f0."default_province", f0."matrix_rows", f0."matrix_columns", f0."matrix_type", f0."selection_type", f0."image_caption_position", f0."allowed_extensions", f0."max_file_size", f0."multiple_files", f0."max_files", f0."category", f0."visibility_condition", f0."required_condition", f0."order", f0."required", f0."validation_rules", f0."form_id", f0."page_id", f0."inserted_at", f0."updated_at", f0."page_id" FROM "form_items" AS f0 WHERE (f0."page_id" = $1) ORDER BY f0."page_id", f0."order" ["6b67f044-ae73-4e70-9908-0c1d20b82e7b"]
Apr 06 15:16:35 co mix[2408038]: ↳ MyAppWeb.FormLive.Submit.get_published_form/1, at: lib/my_app_web/live/form_live/submit.ex:17
Apr 06 15:16:35 co mix[2408038]: [debug] QUERY OK source="item_options" db=1.5ms idle=1197.8ms
Apr 06 15:16:35 co mix[2408038]: SELECT i0."id", i0."label", i0."value", i0."order", i0."form_item_id", i0."inserted_at", i0."updated_at", i0."form_item_id" FROM "item_options" AS i0 WHERE (i0."form_item_id" = ANY($1)) ORDER BY i0."form_item_id" [["b1510b1b-a057-4f36-ac21-7b0f8752f478", "fe01d45d-fb33-4a47-b19c-fdd53b35d93e", "0ac1ad61-fb50-4093-9e27-eebd1cf87220", "6ee4605a-31e9-4a29-85d9-fdbed90838f2", "831714d9-96f3-4f16-b1ef-b0f9fe24bd5d", "d671e37b-025c-4558-808a-b460bfc4d3d4", "9a32f3e9-5f11-421a-9f42-d76ac6c2678f", "f8570bad-eb96-44fb-b276-eb75a853c2c0", "022eb894-9eeb-429d-b5d7-6683a2e35864", "a8b1997b-6901-4fb3-9bcc-3a04af3c56ec", "b84d2614-98e9-49f5-b047-72946bc07e9b", "8a0f5666-ac23-49b2-b2e3-6ce5c28fa697", "ea81ee99-c3ff-47ca-9966-7935d597070a", "414eac01-0022-4862-af03-4929ba2bf50b", "4b8e6847-d985-494c-9afe-74ce712a51d8"]]
Apr 06 15:16:35 co mix[2408038]: ↳ MyAppWeb.FormLive.Submit.get_published_form/1, at: lib/my_app_web/live/form_live/submit.ex:17
Apr 06 15:16:35 co mix[2408038]: [debug] QUERY OK source="item_options" db=0.5ms queue=0.1ms idle=1199.9ms
Apr 06 15:16:35 co mix[2408038]: SELECT i0."id", i0."label", i0."value", i0."order", i0."form_item_id", i0."inserted_at", i0."updated_at", i0."form_item_id" FROM "item_options" AS i0 WHERE (i0."form_item_id" = ANY($1)) ORDER BY i0."form_item_id" [["b1510b1b-a057-4f36-ac21-7b0f8752f478", "fe01d45d-fb33-4a47-b19c-fdd53b35d93e", "0ac1ad61-fb50-4093-9e27-eebd1cf87220", "6ee4605a-31e9-4a29-85d9-fdbed90838f2", "831714d9-96f3-4f16-b1ef-b0f9fe24bd5d", "d671e37b-025c-4558-808a-b460bfc4d3d4", "9a32f3e9-5f11-421a-9f42-d76ac6c2678f", "f8570bad-eb96-44fb-b276-eb75a853c2c0", "022eb894-9eeb-429d-b5d7-6683a2e35864", "a8b1997b-6901-4fb3-9bcc-3a04af3c56ec", "b84d2614-98e9-49f5-b047-72946bc07e9b", "8a0f5666-ac23-49b2-b2e3-6ce5c28fa697", "ea81ee99-c3ff-47ca-9966-7935d597070a", "414eac01-0022-4862-af03-4929ba2bf50b", "4b8e6847-d985-494c-9afe-74ce712a51d8"]]
Apr 06 15:16:35 co mix[2408038]: ↳ MyAppWeb.FormLive.Submit.get_published_form/1, at: lib/my_app_web/live/form_live/submit.ex:17
Apr 06 15:16:35 co mix[2408038]: \n===== Detailed Option Labels in Submit Mount =====
Apr 06 15:16:35 co mix[2408038]: Item: 修改后的文本问题 (ID: fe01d45d-fb33-4a47-b19c-fdd53b35d93e, Type: radio)
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项A"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项C"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项B"
Apr 06 15:16:35 co mix[2408038]: Item: are you ok (ID: 0ac1ad61-fb50-4093-9e27-eebd1cf87220, Type: radio)
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项D"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项A"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项B"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项C"
Apr 06 15:16:35 co mix[2408038]: Item: 你是谁 (ID: 6ee4605a-31e9-4a29-85d9-fdbed90838f2, Type: dropdown)
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项B"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项C"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项D"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项A"
Apr 06 15:16:35 co mix[2408038]: Item: 多选 (ID: 831714d9-96f3-4f16-b1ef-b0f9fe24bd5d, Type: checkbox)
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项A"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项B"
Apr 06 15:16:35 co mix[2408038]:     Option Label: "选项C"
Apr 06 15:16:35 co mix[2408038]: ===== Detailed Option Labels End =====\n
Apr 06 15:16:35 co mix[2408038]: ===== 表单提交页面调试信息 =====
Apr 06 15:16:35 co mix[2408038]: 表单ID: b8fd73c1-c966-43e6-935f-06a893313ebd
Apr 06 15:16:35 co mix[2408038]: 表单项数量: 15
Apr 06 15:16:35 co mix[2408038]: 表单项: b1510b1b-a057-4f36-ac21-7b0f8752f478 (你是谁呢) - 类型: text_input - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: fe01d45d-fb33-4a47-b19c-fdd53b35d93e (修改后的文本问题) - 类型: radio - 选项: 3个选项
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 29e2cece-d1b8-4ff7-bdba-cfcbce9a346a, 标签: 选项A, 值: 我是🐷
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: ba717815-5824-4be6-bdb9-53d791d899c9, 标签: 选项C, 值: 我是🐑
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 9745df89-9e6c-44d0-b4b1-cbbe2e6fd5d6, 标签: 选项B, 值: 我是🐂
Apr 06 15:16:35 co mix[2408038]: 表单项: 0ac1ad61-fb50-4093-9e27-eebd1cf87220 (are you ok) - 类型: radio - 选项: 4个选项
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 15517205-d8d4-4131-b7da-cd8b7ce20dab, 标签: 选项D, 值: option_d
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 15e05919-d9ac-4904-ac0b-9da1dea5ff33, 标签: 选项A, 值: ok
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 656f4563-e910-4752-93a6-7e201b946689, 标签: 选项B, 值: 不ok
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: d14264c9-71ca-4507-aee0-a1a2fd5da0b3, 标签: 选项C, 值: option_c
Apr 06 15:16:35 co mix[2408038]: 表单项: 6ee4605a-31e9-4a29-85d9-fdbed90838f2 (你是谁) - 类型: dropdown - 选项: 4个选项
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: b130d9a6-3cc9-48dc-b984-fb66e2b5f059, 标签: 选项B, 值: 外星人
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: e51d9cce-514f-4e4c-902f-5671ae152176, 标签: 选项C, 值: 机器人
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 4f7fdccc-5444-43e5-a49e-22bdf7ba4516, 标签: 选项D, 值: option_d
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 89fcd624-f12d-4976-9583-f2649c104fb8, 标签: 选项A, 值: 人
Apr 06 15:16:35 co mix[2408038]: 表单项: 831714d9-96f3-4f16-b1ef-b0f9fe24bd5d (多选) - 类型: checkbox - 选项: 3个选项
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 14e9f4a1-c0dc-4fab-81e6-343a4612dc73, 标签: 选项A, 值: option_a
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: d0999716-79f1-42ec-95cb-ba1766b9b3ae, 标签: 选项B, 值: option_b
Apr 06 15:16:35 co mix[2408038]:   - 选项ID: 20c3d890-5225-4a36-92e0-b634e2b01def, 标签: 选项C, 值: option_c
Apr 06 15:16:35 co mix[2408038]: 表单项: d671e37b-025c-4558-808a-b460bfc4d3d4 (数字测试) - 类型: number - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: 9a32f3e9-5f11-421a-9f42-d76ac6c2678f (日期测试？) - 类型: date - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: f8570bad-eb96-44fb-b276-eb75a853c2c0 (时间测试) - 类型: time - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: 022eb894-9eeb-429d-b5d7-6683a2e35864 (地区测试) - 类型: region - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: a8b1997b-6901-4fb3-9bcc-3a04af3c56ec (评分测试) - 类型: rating - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: b84d2614-98e9-49f5-b047-72946bc07e9b (gh) - 类型: rating - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: 8a0f5666-ac23-49b2-b2e3-6ce5c28fa697 (文件) - 类型: file_upload - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: ea81ee99-c3ff-47ca-9966-7935d597070a (图片) - 类型: image_choice - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: 414eac01-0022-4862-af03-4929ba2bf50b (新矩阵题) - 类型: matrix - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 表单项: 4b8e6847-d985-494c-9afe-74ce712a51d8 (新矩阵题) - 类型: matrix - 选项: 0个选项
Apr 06 15:16:35 co mix[2408038]: 当前页面表单项数量: 15
Apr 06 15:16:35 co mix[2408038]: ===== 调试信息结束 =====
Apr 06 15:16:35 co mix[2408038]: [debug] Replied in 15ms
Apr 06 15:16:35 co mix[2408038]: [debug] HANDLE PARAMS in MyAppWeb.FormLive.Submit
Apr 06 15:16:35 co mix[2408038]:   Parameters: %{"id" => "b8fd73c1-c966-43e6-935f-06a893313ebd"}
Apr 06 15:16:35 co mix[2408038]: [debug] Replied in 171µs
